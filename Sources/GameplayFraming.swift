import Foundation

struct GameplayFraming: Equatable {
    let cameraScale: Double
    let playerColliderHeight: Double
    let lowerControlMargin: Double

    func primaryLowerControlBandTop(hudLayout: HUDControlLayout) -> Double {
        let kinds: [HUDControlKind] = [.focus, .attack, .jump]
        return kinds.map { kind in
            let target = hudLayout.target(for: kind)
            return target.center.y - target.visualRadius
        }.min() ?? hudLayout.viewHeight
    }

    func cameraBaseY(
        sceneHeight: Double,
        playerGroundCenterY: Double,
        hudLayout: HUDControlLayout
    ) -> Double {
        let safeBandTop = primaryLowerControlBandTop(hudLayout: hudLayout) - lowerControlMargin
        let playerFeetY = playerGroundCenterY - playerColliderHeight * 0.5

        // Screen Y is top-origin in HUD layout space. Solve the camera transform so
        // the player's feet remain above the primary lower control band.
        let desiredCameraY = playerFeetY + cameraScale * (safeBandTop - sceneHeight * 0.5)

        // Never shift the camera upward past scene center while solving a HUD overlap.
        return min(sceneHeight * 0.5, desiredCameraY)
    }

    func screenYFromTop(
        worldY: Double,
        cameraY: Double,
        sceneHeight: Double
    ) -> Double {
        sceneHeight * 0.5 - (worldY - cameraY) / cameraScale
    }
}
