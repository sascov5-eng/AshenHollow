import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let fileManager = FileManager.default
let spritePath = "Resources/Player/player_run.png"
let scenePath = "Sources/GameScene.swift"
let workflowPath = ".github/workflows/build-ipa.yml"

expect(fileManager.fileExists(atPath: spritePath), "player sprite must exist at \(spritePath)")

let scene = try String(contentsOfFile: scenePath, encoding: .utf8)
expect(scene.contains("SKSpriteNode"), "GameScene must use SKSpriteNode for the player visual")
expect(scene.contains("player_run"), "GameScene must load the player_run sprite sheet")
expect(scene.contains("PlayerSpriteAnimator"), "GameScene must drive the sprite through PlayerSpriteAnimator")

let workflow = try String(contentsOfFile: workflowPath, encoding: .utf8)
expect(workflow.contains("Resources/Player"), "build workflow must copy player sprite resources into the app bundle")
expect(workflow.contains("player_run.png"), "build workflow must verify player_run.png is bundled")

print("PASS: player sprite integration contract")
