import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let fileManager = FileManager.default
let spriteDirectory = "Resources/Player"
let animatorPath = "Sources/PlayerSpriteAnimator.swift"
let runtimePath = "Sources/V21RuntimeContext.swift"
let gameViewPath = "Sources/GameView.swift"
let workflowPath = ".github/workflows/build-ipa-v24-sprite.yml"

let parts = (try fileManager.contentsOfDirectory(atPath: spriteDirectory))
    .filter { $0.hasPrefix("player_run.part") && $0.hasSuffix(".b64") }
    .sorted()
expect(parts.count == 7, "player sprite must be stored in exactly seven ordered data parts")

let animator = try String(contentsOfFile: animatorPath, encoding: .utf8)
expect(animator.contains("final class PlayerSpriteAnimator"), "player sprite animator must exist")
expect(animator.contains("SKSpriteNode"), "player visual must use SKSpriteNode")
expect(animator.contains("player_run"), "animator must load the player_run sprite sheet")
expect(animator.contains("let columns = 4"), "sprite sheet must use four columns")
expect(animator.contains("let rows = 2"), "sprite sheet must use two rows")

let runtime = try String(contentsOfFile: runtimePath, encoding: .utf8)
expect(runtime.contains("PlayerSpriteRuntimeInstaller.install(on: scene)"), "V24 runtime must install the player sprite")

let gameView = try String(contentsOfFile: gameViewPath, encoding: .utf8)
expect(gameView.contains("import SpriteKit"), "GameView must import SpriteKit")
expect(gameView.contains("SpriteView("), "GameView must present the SpriteKit scene")
expect(gameView.contains("GameScene("), "GameView must create GameScene")
expect(gameView.contains("V21RuntimeBootstrap.install(on: scene, launchMode: launchMode)"), "GameView must install the V24 runtime after the scene is attached")
expect(gameView.contains("V24 BUILD TEST"), "diagnostic V24 marker must identify the exact installed build")
expect(!gameView.contains("iOS launch test"), "temporary launch-test screen must not replace gameplay")

let workflow = try String(contentsOfFile: workflowPath, encoding: .utf8)
expect(workflow.contains("Resources/Player/player_run.part*.b64"), "sprite build must reconstruct the PNG from source data")
expect(workflow.contains("Resources/Player/player_run.png"), "sprite build must bundle player_run.png")
expect(workflow.contains("AshenHollow-V24-Sprite-unsigned.ipa"), "sprite build must package the V24 sprite IPA")

print("PASS: player sprite integration contract")
