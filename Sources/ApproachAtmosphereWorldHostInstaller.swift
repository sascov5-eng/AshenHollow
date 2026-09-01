import SpriteKit

enum ApproachAtmosphereWorldHostInstaller {
    private static let actionKey = "approachAtmosphereWorldHostRuntime"

    static func install(on scene: SKScene, context: V21RuntimeContext) {
        scene.removeAction(forKey: actionKey)

        let action = SKAction.customAction(withDuration: 1_000_000) { node, _ in
            guard let scene = node as? SKScene,
                  let worldRoot = scene.childNode(withName: ApproachAtmosphereLayeringPolicy.hostNodeName) else {
                return
            }

            if context.activeRoomID != .approach {
                worldRoot.childNode(withName: ApproachAtmosphereLayeringPolicy.atmosphereNodeName)?.removeFromParent()
                return
            }

            if let root = scene.childNode(withName: ApproachAtmosphereLayeringPolicy.atmosphereNodeName),
               root.parent !== worldRoot {
                root.removeFromParent()
                root.zPosition = CGFloat(ApproachAtmosphereLayeringPolicy.rootZPosition)
                worldRoot.addChild(root)
            }

            guard let atmosphereRoot = worldRoot.childNode(withName: ApproachAtmosphereLayeringPolicy.atmosphereNodeName),
                  let camera = scene.camera else {
                return
            }

            let cameraOffset = Double(camera.position.x) - ApproachAtmosphereLayeringPolicy.roomCenterX

            atmosphereRoot.childNode(withName: ApproachAtmosphereLayeringPolicy.farNodeName)?.position.x = CGFloat(
                cameraOffset * (1.0 - ApproachAtmosphereLayeringPolicy.farParallax)
            )
            atmosphereRoot.childNode(withName: ApproachAtmosphereLayeringPolicy.midNodeName)?.position.x = CGFloat(
                cameraOffset * (1.0 - ApproachAtmosphereLayeringPolicy.midParallax)
            )
            atmosphereRoot.childNode(withName: ApproachAtmosphereLayeringPolicy.hazeNodeName)?.position.x = CGFloat(
                cameraOffset * (1.0 - ApproachAtmosphereLayeringPolicy.hazeParallax)
            )
        }

        scene.run(action, withKey: actionKey)
    }
}
