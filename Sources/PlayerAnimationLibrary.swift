import SpriteKit
import UIKit

enum PlayerAnimationKey: String, CaseIterable {
    case idle
    case run
    case jump
    case fall
    case dash
    case attack1
    case attack2
    case attackUp
    case attackDown
    case hurt
    case death
}

struct PlayerAnimationLibrary {
    private var storage: [PlayerAnimationKey: [SKTexture]] = [:]

    init(bundle: Bundle = .main) {
        let specs: [(PlayerAnimationKey, String, Int)] = [
            (.idle, "Idle.png", 4),
            (.run, "Run.png", 4),
            (.jump, "Jump.png", 4),
            (.fall, "Fall.png", 4),
            (.dash, "Dash.png", 4),
            (.attack1, "Attack1.png", 4),
            (.attack2, "Attack2.png", 4),
            (.attackUp, "AttackUp.png", 4),
            (.attackDown, "AttackDown.png", 4),
            (.hurt, "Hurt.png", 4),
            (.death, "Death.png", 4)
        ]

        for (key, filename, frameCount) in specs {
            let url = bundle.bundleURL
                .appendingPathComponent("PlayerAnimations", isDirectory: true)
                .appendingPathComponent(filename)

            guard
                let data = try? Data(contentsOf: url),
                let image = UIImage(data: data),
                let cgImage = image.cgImage
            else {
                continue
            }

            let sheet = SKTexture(cgImage: cgImage)
            sheet.filteringMode = .linear
            storage[key] = Self.frames(from: sheet, count: frameCount)
        }
    }

    func frames(for key: PlayerAnimationKey) -> [SKTexture] {
        storage[key] ?? storage[.idle] ?? []
    }

    func frameDuration(for key: PlayerAnimationKey) -> TimeInterval {
        switch key {
        case .idle: return 0.14
        case .run: return 0.08
        case .jump: return 0.07
        case .fall: return 0.09
        case .dash: return 0.05
        case .attack1, .attack2: return 0.055
        case .attackUp, .attackDown: return 0.055
        case .hurt: return 0.07
        case .death: return 0.10
        }
    }

    func loops(_ key: PlayerAnimationKey) -> Bool {
        switch key {
        case .idle, .run, .fall:
            return true
        default:
            return false
        }
    }

    private static func frames(from sheet: SKTexture, count: Int) -> [SKTexture] {
        guard count > 0 else { return [] }
        let width = 1.0 / CGFloat(count)

        return (0..<count).map { index in
            let texture = SKTexture(
                rect: CGRect(
                    x: CGFloat(index) * width,
                    y: 0,
                    width: width,
                    height: 1
                ),
                in: sheet
            )
            texture.filteringMode = .linear
            return texture
        }
    }
}
