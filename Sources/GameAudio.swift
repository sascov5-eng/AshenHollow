import AVFoundation
import Foundation

enum GameSound: String, CaseIterable {
    case jump
    case wallJump
    case land
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
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for sound in GameSound.allCases {
            let data = Self.wavData(for: sound)
            var pool: [AVAudioPlayer] = []
            for _ in 0..<3 {
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

    private static func volume(for sound: GameSound) -> Float {
        switch sound {
        case .jump: return 0.55
        case .wallJump: return 0.62
        case .land: return 0.48
        case .attack: return 0.7
        case .dash: return 0.52
        case .heal: return 0.4
        case .healComplete: return 0.5
        }
    }

    private static func wavData(for sound: GameSound) -> Data {
        let sampleRate = 22050
        let duration: Double
        switch sound {
        case .jump: duration = 0.14
        case .wallJump: duration = 0.16
        case .land: duration = 0.12
        case .attack: duration = 0.18
        case .dash: duration = 0.2
        case .heal: duration = 0.35
        case .healComplete: duration = 0.28
        }

        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)

        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = envelope(t, duration: duration, attack: 0.008, release: duration * 0.45)
            let value: Double
            switch sound {
            case .jump:
                let freq = lerp(240, 520, t / duration)
                value = square(t, freq: freq) * 0.22 + sine(t, freq: freq * 2) * 0.08
            case .wallJump:
                let freq = lerp(320, 680, t / duration)
                value = square(t, freq: freq) * 0.2 + sine(t, freq: freq * 1.5) * 0.1
            case .land:
                value = sine(t, freq: 90) * 0.28 * exp(-t * 18) + noise() * 0.12 * exp(-t * 22)
            case .attack:
                let whoosh = noise() * (1 - t / duration)
                let blade = sine(t, freq: lerp(880, 220, t / duration)) * exp(-t * 14)
                value = whoosh * 0.18 + blade * 0.22 + square(t, freq: 140) * 0.05 * exp(-t * 20)
            case .dash:
                value = noise() * 0.2 * (1 - t / duration) + sine(t, freq: lerp(420, 140, t / duration)) * 0.12
            case .heal:
                value = sine(t, freq: 392) * 0.12 + sine(t, freq: 494) * 0.1 + sine(t, freq: 587) * 0.08
            case .healComplete:
                value = sine(t, freq: 523) * 0.14 + sine(t, freq: 659) * 0.11 + sine(t, freq: 784) * 0.08
            }
            let clipped = max(-1, min(1, value * env))
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

    private static func noise() -> Double {
        Double.random(in: -1...1)
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
}
