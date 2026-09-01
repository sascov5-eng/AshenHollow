import Foundation

func validateGameSceneInputLockContract(_ scene: GameScene) {
    scene.setExternalInputLocked(true)
    let locked: Bool = scene.externalInputLocked
    scene.setExternalInputLocked(false)
    _ = locked
}
