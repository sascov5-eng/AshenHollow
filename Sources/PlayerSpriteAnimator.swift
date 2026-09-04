import Foundation
import SpriteKit
import UIKit

final class PlayerSpriteAnimator: NSObject {
    private enum MotionState {
        case idle
        case run
        case airborne
    }

    let sprite = SKSpriteNode()

    private var runFrames: [SKTexture] = []
    private var motionState: MotionState = .idle
    private var lastPlayerPosition: CGPoint?
    private var facing: CGFloat = 1

    func install(on player: SKNode, visualContainer: SKShapeNode, scene: SKScene) -> Bool {
        guard loadFramesIfNeeded(), let firstFrame = runFrames.first else {
            return false
        }

        visualContainer.fillColor = .clear
        visualContainer.strokeColor = .clear

        for name in ["face", "leftFoot", "rightFoot", "glow"] {
            visualContainer.childNode(withName: name)?.isHidden = true
        }

        sprite.removeFromParent()
        sprite.removeAllActions()
        sprite.name = "playerSprite"
        sprite.texture = firstFrame
        sprite.size = CGSize(width: 96, height: 96)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.position = CGPoint(x: 0, y: -1)
        sprite.zPosition = -0.25
        sprite.xScale = 1
        sprite.yScale = 1
        visualContainer.addChild(sprite)

        lastPlayerPosition = player.position
        motionState = .idle
        facing = 1

        scene.removeAction(forKey: "playerSpriteRuntime")
        let tick = SKAction.customAction(withDuration: 1_000_000) { [weak self, weak player] _, _ in
            guard let self, let player else { return }
            self.update(playerPosition: player.position)
        }
        scene.run(tick, withKey: "playerSpriteRuntime")
        return true
    }

    private func loadFramesIfNeeded() -> Bool {
        if !runFrames.isEmpty {
            return true
        }

        guard let path = Bundle.main.path(
            forResource: "player_run",
            ofType: "png",
            inDirectory: "Resources/Player"
        ), let image = UIImage(contentsOfFile: path) else {
            return false
        }

        let sheet = SKTexture(image: image)
        sheet.filteringMode = .linear

        let columns = 4
        let rows = 2
        var frames: [SKTexture] = []
        frames.reserveCapacity(columns * rows)

        for visualRow in 0..<rows {
            let textureRow = rows - 1 - visualRow
            for column in 0..<columns {
                let rect = CGRect(
                    x: CGFloat(column) / CGFloat(columns),
                    y: CGFloat(textureRow) / CGFloat(rows),
                    width: 1.0 / CGFloat(columns),
                    height: 1.0 / CGFloat(rows)
                )
                let texture = SKTexture(rect: rect, in: sheet)
                texture.filteringMode = .linear
                frames.append(texture)
            }
        }

        runFrames = frames
        return runFrames.count == 8
    }

    private func update(playerPosition: CGPoint) {
        guard let previous = lastPlayerPosition else {
            lastPlayerPosition = playerPosition
            return
        }

        let dx = playerPosition.x - previous.x
        let dy = playerPosition.y - previous.y
        lastPlayerPosition = playerPosition

        if abs(dx) > 0.05 {
            facing = dx > 0 ? 1 : -1
        }
        sprite.xScale = facing

        let newState: MotionState
        if abs(dy) > 0.45 {
            newState = .airborne
        } else if abs(dx) > 0.12 {
            newState = .run
        } else {
            newState = .idle
        }

        guard newState != motionState else { return }
        motionState = newState

        switch newState {
        case .run:
            startRunAnimation()
        case .idle, .airborne:
            stopRunAnimation()
        }
    }

    private func startRunAnimation() {
        guard !runFrames.isEmpty else { return }
        sprite.removeAction(forKey: "run")
        let cycle = SKAction.animate(
            with: runFrames,
            timePerFrame: 0.075,
            resize: false,
            restore: false
        )
        sprite.run(SKAction.repeatForever(cycle), withKey: "run")
    }

    private func stopRunAnimation() {
        sprite.removeAction(forKey: "run")
        sprite.texture = runFrames.first
    }
}

enum PlayerSpriteRuntimeInstaller {
    static func install(on scene: SKScene) {
        guard let player = scene.childNode(withName: "player") else {
            return
        }

        let visualContainer = player.children
            .compactMap { $0 as? SKShapeNode }
            .first { $0.name != "attackHitbox" }

        guard let visualContainer else {
            return
        }

        let animator = PlayerSpriteAnimator()
        guard animator.install(on: player, visualContainer: visualContainer, scene: scene) else {
            return
        }

        scene.userData = scene.userData ?? NSMutableDictionary()
        scene.userData?["playerSpriteAnimator"] = animator
    }
}
