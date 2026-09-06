import AVFoundation
import Foundation

enum GameSound: String, CaseIterable {
    case jump
    case wallJump
    case land
    case footstep
    case attack
    case dash
    case heal
    case healComplete
}

final class GameAudio {
    private var players: [GameSound: [AVAudioPlayer]] = [:]
    private var nextSlot: [GameSound: Int] = [:]
    private var prepared = false

    func prepare() {
        guard !prepared else { return }
        prepared = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for sound in GameSound.allCases {
            var pool: [AVAudioPlayer] = []
            let copies = sound == .footstep ? 4 : 3
            for slot in 0..<copies {
                let data = Self.wavData(for: sound, variant: slot)
                if let player = try? AVAudioPlayer(data: data) {
                    player.prepareToPlay()
                    player.volume = Self.volume(for: sound)
                    pool.append(player)
                }
            }
            players[sound] = pool
            nextSlot[sound] = 0
        }
    }

    func play(_ sound: GameSound) {
        if !prepared { prepare() }
        guard let pool = players[sound], !pool.isEmpty else { return }
        let index = nextSlot[sound] ?? 0
        nextSlot[sound] = (index + 1) % pool.count
        let player = pool[index]
        player.currentTime = 0
        player.play()
    }

    func stop(_ sound: GameSound) {
        players[sound]?.forEach { $0.stop() }
    }

    private var ambiencePlayer: AVAudioPlayer?

    func startAmbience() {
        if !prepared { prepare() }
        guard ambiencePlayer == nil else { return }
        if let player = try? AVAudioPlayer(data: Self.ambienceWav()) {
            player.numberOfLoops = -1
            player.volume = 0.20
            player.prepareToPlay()
            player.play()
            ambiencePlayer = player
        }
    }

    private static func volume(for sound: GameSound) -> Float {
        switch sound {
        case .jump: return 0.72
        case .wallJump: return 0.78
        case .land: return 0.64
        case .footstep: return 0.42
        case .attack: return 0.86
        case .dash: return 0.74
        case .heal: return 0.48
        case .healComplete: return 0.62
        }
    }

    private static func wavData(for sound: GameSound, variant: Int) -> Data {
        let sampleRate = 22050
        let duration: Double
        switch sound {
        case .jump: duration = 0.13
        case .wallJump: duration = 0.15
        case .land: duration = 0.14
        case .footstep: duration = 0.09
        case .attack: duration = 0.17
        case .dash: duration = 0.22
        case .heal: duration = 1.02
        case .healComplete: duration = 0.34
        }

        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        let seed = sound.hashValue &* 17 &+ variant &* 131

        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let n = noise(i, seed: seed)
            let env = envelope(t, duration: duration, attack: 0.006, release: duration * 0.42)
            let value: Double
            switch sound {
            case .jump:
                let hop = sine(t, freq: lerp(280, 640, t / duration)) * exp(-t * 10)
                let body = square(t, freq: lerp(170, 90, t / duration)) * exp(-t * 22) * 0.22
                let click = n * exp(-t * 70) * 0.18
                value = hop * 0.34 + body + click
            case .wallJump:
                let hop = sine(t, freq: lerp(360, 820, t / duration)) * exp(-t * 9)
                let kick = square(t, freq: lerp(220, 110, t / duration)) * exp(-t * 18) * 0.2
                let grit = n * exp(-t * 40) * 0.16
                value = hop * 0.32 + kick + grit
            case .land:
                let thud = sine(t, freq: 72) * exp(-t * 16) * 0.42
                let boot = sine(t, freq: 140) * exp(-t * 22) * 0.16
                let grit = n * exp(-t * 28) * 0.22
                value = thud + boot + grit
            case .footstep:
                let pitch = 96 + Double(variant % 4) * 12
                let tap = sine(t, freq: pitch) * exp(-t * 38) * 0.34
                let leather = n * exp(-t * 48) * 0.2
                let stone = sine(t, freq: pitch * 2.4) * exp(-t * 55) * 0.08
                value = tap + leather + stone
            case .attack:
                let swipe = n * (1 - t / duration) * exp(-t * 8) * 0.34
                let blade = sine(t, freq: lerp(1480, 280, pow(t / duration, 0.65))) * exp(-t * 11) * 0.28
                let metal = square(t, freq: lerp(620, 180, t / duration)) * exp(-t * 24) * 0.08
                let tick = n * exp(-t * 90) * 0.22
                value = swipe + blade + metal + tick
            case .dash:
                let whoosh = n * pow(1 - t / duration, 1.35) * 0.36
                let dive = sine(t, freq: lerp(540, 90, t / duration)) * exp(-t * 7) * 0.18
                let boom = sine(t, freq: 68) * exp(-t * 14) * 0.22
                value = whoosh + dive + boom
            case .heal:
                let swell = envelope(t, duration: duration, attack: 0.12, release: 0.22)
                let a = sine(t, freq: 329.63) * 0.12
                let b = sine(t, freq: 392.00) * 0.11
                let c = sine(t, freq: 493.88) * 0.09
                let shimmer = sine(t, freq: 783.99 + sin(t * 6) * 8) * 0.04
                value = (a + b + c + shimmer) * swell
            case .healComplete:
                let chime = sine(t, freq: 523.25) * exp(-t * 5) * 0.18
                    + sine(t, freq: 659.25) * exp(-t * 6) * 0.14
                    + sine(t, freq: 783.99) * exp(-t * 7) * 0.1
                let sparkle = n * exp(-t * 30) * 0.04
                value = chime + sparkle
            }
            let clipped = max(-1, min(1, value * (sound == .heal ? 1 : env)))
            samples[i] = Int16(clipped * Double(Int16.max - 1))
        }

        return makeWav(samples: samples, sampleRate: sampleRate)
    }

    private static func envelope(_ t: Double, duration: Double, attack: Double, release: Double) -> Double {
        let a = min(1, t / max(0.001, attack))
        let rStart = max(attack, duration - release)
        let r = t < rStart ? 1 : max(0, 1 - (t - rStart) / max(0.001, release))
        return a * r
    }

    private static func sine(_ t: Double, freq: Double) -> Double {
        sin(2 * Double.pi * freq * t)
    }

    private static func square(_ t: Double, freq: Double) -> Double {
        sine(t, freq: freq) >= 0 ? 1 : -1
    }

    private static func noise(_ i: Int, seed: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: i &* 374761393 &+ seed &* 668265263)
        x = (x ^ (x >> 13)) &* 1274126177
        let u = Double(x & 0x7fffffff) / Double(0x7fffffff)
        return u * 2 - 1
    }

    private static func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double {
        a + (b - a) * max(0, min(1, x))
    }

    private static func makeWav(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        func appendASCII(_ s: String) { data.append(contentsOf: s.utf8) }
        func appendU32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendU16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendU32(UInt32(36 + dataSize))
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendU32(16)
        appendU16(1)
        appendU16(1)
        appendU32(UInt32(sampleRate))
        appendU32(UInt32(sampleRate * 2))
        appendU16(2)
        appendU16(16)
        appendASCII("data")
        appendU32(UInt32(dataSize))
        for sample in samples {
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }

    private static func ambienceWav() -> Data {
        let sampleRate = 22050
        let duration = 4.0
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let drone = sine(t, freq: 46) * 0.11 + sine(t, freq: 69) * 0.07 + sine(t, freq: 92.5) * 0.04
            let air = noise(i, seed: 901) * 0.03 * (0.5 + 0.5 * sine(t, freq: 0.18))
            var drip = 0.0
            let dripT = t.truncatingRemainder(dividingBy: 1.65)
            if dripT < 0.09 { drip = sine(dripT, freq: 1760) * exp(-dripT * 38) * 0.09 }
            let value = (drone + air + drip) * 0.9
            let clipped = max(-1, min(1, value))
            samples[i] = Int16(clipped * 24000)
        }
        return makeWav(samples: samples, sampleRate: sampleRate)
    }
}
