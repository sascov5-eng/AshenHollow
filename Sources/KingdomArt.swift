import SpriteKit
import UIKit
import AVFoundation

enum KingdomArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        let url = Bundle.main.bundleURL.appendingPathComponent("Kingdom").appendingPathComponent(name)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[name] = texture
        return texture
    }
}

enum CharmID: String, CaseIterable {
    case shell, nail, soul, shadow

    var title: String {
        switch self {
        case .shell: return "Прочный панцирь"
        case .nail: return "Острый гвоздь"
        case .soul: return "Ловец души"
        case .shadow: return "Теневой шаг"
        }
    }

    var detail: String {
        switch self {
        case .shell: return "Ещё одна маска"
        case .nail: return "Удар наносит 2 урона"
        case .soul: return "Больше света с удара"
        case .shadow: return "Рывок дальше"
        }
    }

    var icon: String {
        switch self {
        case .shell: return "charm_a.png"
        case .nail: return "charm_b.png"
        case .soul: return "charm_c.png"
        case .shadow: return "charm_d.png"
        }
    }
}

final class KingdomDirector {
    private(set) var geo = 0
    private(set) var ownedCharms: Set<CharmID> = []
    private(set) var areaName = "Пепельный крест"
    private var lastArea = ""
    private var music: AVAudioPlayer?
    private var currentTrack = ""
    private weak var hudRoot: SKNode?
    private var maskNodes: [SKShapeNode] = []
    private var soulFill: SKShapeNode?
    private var geoLabel: SKLabelNode?
    private var areaLabel: SKLabelNode?
    private var toastLabel: SKLabelNode?
    private var collectedPickups: Set<String> = []
    private var spokenNPCs: Set<String> = []

    var extraMasks: Int { ownedCharms.contains(.shell) ? 1 : 0 }
    var nailDamage: Int { ownedCharms.contains(.nail) ? 2 : 1 }
    var soulBonus: Bool { ownedCharms.contains(.soul) }
    var dashMultiplier: CGFloat { ownedCharms.contains(.shadow) ? 1.28 : 1 }

    func install(on hud: SKNode, camera: SKCameraNode) {
        hudRoot = hud
        let root = SKNode()
        root.name = "kingdomHUD"
        root.zPosition = 1200
        hud.addChild(root)

        for _ in 0..<6 {
            let mask = SKShapeNode(circleOfRadius: 11)
            mask.strokeColor = UIColor(white: 0.85, alpha: 0.9)
            mask.lineWidth = 2
            mask.zPosition = 2
            root.addChild(mask)
            maskNodes.append(mask)
        }
        let soulRing = SKShapeNode(circleOfRadius: 16)
        soulRing.strokeColor = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 0.9)
        soulRing.lineWidth = 2
        soulRing.name = "soulRing"
        root.addChild(soulRing)
        let fill = SKShapeNode(circleOfRadius: 12)
        fill.fillColor = UIColor(red: 0.35, green: 0.75, blue: 1, alpha: 0.85)
        fill.strokeColor = .clear
        fill.name = "soulFill"
        soulRing.addChild(fill)
        soulFill = fill

        let geo = SKLabelNode(fontNamed: "AvenirNext-Bold")
        geo.fontSize = 13
        geo.fontColor = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1)
        geo.horizontalAlignmentMode = .left
        geo.zPosition = 3
        root.addChild(geo)
        geoLabel = geo

        let area = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        area.fontSize = 16
        area.fontColor = UIColor(white: 0.92, alpha: 0.95)
        area.horizontalAlignmentMode = .center
        area.zPosition = 4
        root.addChild(area)
        areaLabel = area

        let toast = SKLabelNode(fontNamed: "AvenirNext-Medium")
        toast.fontSize = 13
        toast.fontColor = UIColor(white: 0.9, alpha: 1)
        toast.horizontalAlignmentMode = .center
        toast.zPosition = 5
        toast.alpha = 0
        root.addChild(toast)
        toastLabel = toast

        placeNPCs(in: camera.scene)
        placeCharms(in: camera.scene)
        playMusic("music_crossroads.wav")
    }

    func layout(viewport: CGSize) {
        let halfW = viewport.width * 0.5
        let halfH = viewport.height * 0.5
        for (i, mask) in maskNodes.enumerated() {
            mask.position = CGPoint(x: -halfW + 28 + CGFloat(i) * 26, y: halfH - 28)
        }
        hudRoot?.childNode(withName: "//soulRing")?.position = CGPoint(x: -halfW + 28, y: halfH - 58)
        geoLabel?.position = CGPoint(x: -halfW + 52, y: halfH - 64)
        areaLabel?.position = CGPoint(x: 0, y: halfH - 30)
        toastLabel?.position = CGPoint(x: 0, y: -halfH + 118)
    }

    func refresh(hp: Int, maxHP: Int, soul: Int, soulMax: Int, playerX: CGFloat) {
        let masks = maxHP
        for (i, mask) in maskNodes.enumerated() {
            mask.isHidden = i >= masks
            mask.fillColor = i < hp ? UIColor(white: 0.95, alpha: 1) : UIColor(white: 0.12, alpha: 0.85)
        }
        let t = CGFloat(soul) / CGFloat(max(1, soulMax))
        soulFill?.xScale = 0.25 + 0.75 * t
        soulFill?.yScale = 0.25 + 0.75 * t
        geoLabel?.text = "Гео \(geo)"
        let next = area(for: playerX)
        if next != lastArea {
            lastArea = next
            areaName = next
            areaLabel?.text = next
            areaLabel?.alpha = 1
            areaLabel?.run(.sequence([.wait(forDuration: 2.2), .fadeOut(withDuration: 1.1)]))
            playMusic(track(for: playerX))
        }
        collectPickups(playerX: playerX)
        speakNPCs(playerX: playerX)
    }

    func addGeo(_ amount: Int) {
        geo += max(0, amount)
        toast("+\(amount) гео")
    }

    func grant(_ charm: CharmID) {
        guard !ownedCharms.contains(charm) else { return }
        ownedCharms.insert(charm)
        toast("Амулет: \(charm.title)")
    }

    func toast(_ text: String) {
        toastLabel?.removeAllActions()
        toastLabel?.text = text
        toastLabel?.alpha = 1
        toastLabel?.run(.sequence([.wait(forDuration: 2.4), .fadeOut(withDuration: 0.6)]))
    }

    private func area(for x: CGFloat) -> String {
        switch x {
        case ..<9000: return "Пепельный крест"
        case ..<15000: return "Моховая тропа"
        case ..<20000: return "Город пыли"
        case ..<24000: return "Костяное гнездо"
        default: return "Сердце пустоты"
        }
    }

    private func track(for x: CGFloat) -> String {
        switch x {
        case ..<9000: return "music_crossroads.wav"
        case ..<15000: return "music_moss.wav"
        case ..<20000: return "music_city.wav"
        case ..<24000: return "music_nest.wav"
        case ..<24600: return "music_void.wav"
        default: return "music_battle.wav"
        }
    }

    private func playMusic(_ name: String) {
        guard name != currentTrack else { return }
        currentTrack = name
        let url = Bundle.main.bundleURL.appendingPathComponent("Kingdom").appendingPathComponent(name)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0.32
        player.play()
        music = player
    }

    private func placeCharms(in scene: SKScene?) {
        guard let scene else { return }
        for pickup in KingdomMap.charms {
            guard let tex = KingdomArt.texture(pickup.charm.icon) else { continue }
            let node = SKSpriteNode(texture: tex)
            node.size = CGSize(width: 42, height: 42)
            node.position = CGPoint(x: pickup.x, y: 148)
            node.zPosition = 24
            node.name = "pickup-\(pickup.id)"
            node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.8), .moveBy(x: 0, y: -8, duration: 0.8)])))
            scene.addChild(node)
        }
    }

    private func collectPickups(playerX: CGFloat) {
        for pickup in KingdomMap.charms where !collectedPickups.contains(pickup.id) {
            if abs(playerX - pickup.x) < 70 {
                collectedPickups.insert(pickup.id)
                grant(pickup.charm)
                hudRoot?.scene?.childNode(withName: "pickup-\(pickup.id)")?.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
            }
        }
    }

    private func placeNPCs(in scene: SKScene?) {
        guard let scene else { return }
        let npcs: [(String, CGFloat, String)] = [
            ("npcCartographer", 1180, "npc_cartographer.png"),
            ("npcStag", 15440, "npc_cartographer.png"),
            ("npcWatcher", 24280, "npc_cartographer.png")
        ]
        for (name, x, icon) in npcs {
            guard let tex = KingdomArt.texture(icon) else { continue }
            let npc = SKSpriteNode(texture: tex)
            npc.size = CGSize(width: 88, height: 88)
            npc.position = CGPoint(x: x, y: 148)
            npc.zPosition = 21
            npc.name = name
            if name == "npcWatcher" { npc.color = UIColor(red: 0.35, green: 0.2, blue: 0.55, alpha: 1); npc.colorBlendFactor = 0.45 }
            if name == "npcStag" { npc.color = UIColor(red: 0.55, green: 0.42, blue: 0.22, alpha: 1); npc.colorBlendFactor = 0.35 }
            scene.addChild(npc)
        }
    }

    private func speakNPCs(playerX: CGFloat) {
        let lines: [(String, CGFloat, String)] = [
            ("npcCartographer", 1180, "Карты врут. Иди глубже."),
            ("npcStag", 15440, "Дальше — крыши Города пыли."),
            ("npcWatcher", 24280, "Король ещё не спит.")
        ]
        for (id, x, line) in lines where !spokenNPCs.contains(id) {
            if abs(playerX - x) < 90 {
                spokenNPCs.insert(id)
                toast(line)
            }
        }
    }
}
