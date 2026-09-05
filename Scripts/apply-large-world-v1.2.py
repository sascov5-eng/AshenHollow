from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()

old_props = '''    private let gameCamera = SKCameraNode()
    private let hud = SKNode()
    private var platformRects: [CGRect] = []
    private var worldWidth: CGFloat = 2200
'''
new_props = '''    private let gameCamera = SKCameraNode()
    private let hud = SKNode()
    private let worldLayout = LargeWorldLayout.blockout
    private var cameraController = CinematicCameraController()
    private var platformRects: [CGRect] = []
'''
if old_props not in text:
    raise SystemExit("v1.2 property integration anchor not found")
text = text.replace(old_props, new_props, 1)

old_camera_constants = '''    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 4.2
    private let cameraLookAhead: CGFloat = 120
    private let cameraVerticalOffset: CGFloat = 22
'''
new_camera_constants = '''    private let cameraZoom: CGFloat = 1.28
'''
if old_camera_constants not in text:
    raise SystemExit("v1.2 camera constants anchor not found")
text = text.replace(old_camera_constants, new_camera_constants, 1)

start = text.index("    private func buildWorld() {")
end = text.index("    private func buildPlayer() {")
new_world = '''    private func buildWorld() {
        platformRects = worldLayout.collisionRects

        let backdrop = SKShapeNode(rectOf: worldLayout.bounds.size)
        backdrop.fillColor = UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldLayout.bounds.midX, y: worldLayout.bounds.midY)
        backdrop.zPosition = -120
        addChild(backdrop)

        for (index, rect) in worldLayout.backgroundRects.enumerated() {
            addDecorRect(
                rect,
                fill: UIColor(
                    red: 0.055 + CGFloat(index % 3) * 0.008,
                    green: 0.065 + CGFloat(index % 2) * 0.008,
                    blue: 0.085 + CGFloat(index % 4) * 0.006,
                    alpha: 0.78
                ),
                z: -70,
                corner: 28
            )
        }

        for rect in worldLayout.collisionRects {
            addDecorRect(
                rect,
                fill: UIColor(red: 0.14, green: 0.155, blue: 0.19, alpha: 1),
                stroke: UIColor(white: 0.46, alpha: 0.28),
                z: 1,
                corner: min(10, min(rect.width, rect.height) * 0.12)
            )
        }

        for rect in worldLayout.foregroundRects {
            addDecorRect(
                rect,
                fill: UIColor(red: 0.015, green: 0.018, blue: 0.026, alpha: 0.58),
                z: 35,
                corner: 18
            )
        }

        let shaftGlow = SKShapeNode(rectOf: CGSize(width: 520, height: 1420), cornerRadius: 90)
        shaftGlow.fillColor = UIColor(red: 0.055, green: 0.09, blue: 0.105, alpha: 0.14)
        shaftGlow.strokeColor = .clear
        shaftGlow.position = CGPoint(x: 4750, y: 850)
        shaftGlow.zPosition = -40
        addChild(shaftGlow)
    }

    private func addDecorRect(
        _ rect: CGRect,
        fill: UIColor,
        stroke: UIColor = .clear,
        z: CGFloat,
        corner: CGFloat
    ) {
        let node = SKShapeNode(rectOf: rect.size, cornerRadius: corner)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = stroke == .clear ? 0 : 2
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.zPosition = z
        addChild(node)
    }

'''
text = text[:start] + new_world + text[end:]

old_spawn = "        player.position = CGPoint(x: 230, y: 130)"
if old_spawn not in text:
    raise SystemExit("v1.2 player spawn anchor not found")
text = text.replace(old_spawn, "        player.position = worldLayout.spawnPoint", 1)

camera_start = text.index("    private func buildCamera() {")
camera_end = text.index("    private func buildHUD() {")
new_build_camera = '''    private func buildCamera() {
        gameCamera.removeFromParent()
        addChild(gameCamera)
        camera = gameCamera
        gameCamera.setScale(cameraZoom)
        gameCamera.position = cameraController.reset(
            playerPosition: player.position,
            viewportSize: size,
            zoom: cameraZoom,
            worldBounds: worldLayout.bounds
        )
    }

'''
text = text[:camera_start] + new_build_camera + text[camera_end:]

update_start = text.index("    private func updateCamera(_ dt: CGFloat) {")
update_end = text.index("    private func updateHUDStatus() {")
new_update_camera = '''    private func updateCamera(_ dt: CGFloat) {
        gameCamera.position = cameraController.update(
            playerPosition: player.position,
            velocity: velocity,
            facing: facing,
            dt: dt,
            viewportSize: size,
            zoom: cameraZoom,
            worldBounds: worldLayout.bounds
        )
    }

'''
text = text[:update_start] + new_update_camera + text[update_end:]

path.write_text(text)
print("APPLIED v1.2 LARGE WORLD + CINEMATIC CAMERA")
