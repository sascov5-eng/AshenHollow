from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f"Missing signature: {label}")

path = Path("Sources/GameScene.swift")
text = path.read_text()

text = replace_once(
    text,
    '''    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 5.0
    private let cameraLookAhead: CGFloat = 95
    private let cameraVerticalOffset: CGFloat = 12
''',
    '''    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 5.0
    private let cameraLookAhead: CGFloat = 95
    private var gameplayFraming: GameplayFraming {
        GameplayFraming(
            cameraScale: Double(cameraZoom),
            playerColliderHeight: movementTuning.colliderHeight,
            lowerControlMargin: 18
        )
    }
''',
    "camera framing property",
)

text = replace_once(
    text,
    '''        gameCamera.position = CGPoint(
            x: startX,
            y: size.height * 0.5 + cameraVerticalOffset
        )
''',
    '''        gameCamera.position = CGPoint(
            x: startX,
            y: gameplayCameraBaseY()
        )
''',
    "camera build base Y",
)

old_layout = '''    private func currentHUDLayout(in skView: SKView? = nil) -> HUDControlLayout {
        let viewWidth = Double(skView?.bounds.width ?? size.width)
        let viewHeight = Double(skView?.bounds.height ?? size.height)
        let safeBottom = Double(skView?.safeAreaInsets.bottom ?? view?.safeAreaInsets.bottom ?? 0)
        return HUDControlLayout(
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            safeBottomInset: safeBottom
        )
    }
'''
new_layout = old_layout + '''
    private func gameplayCameraBaseY() -> CGFloat {
        let layout = currentHUDLayout(in: view)
        return CGFloat(
            gameplayFraming.cameraBaseY(
                sceneHeight: Double(size.height),
                playerGroundCenterY: 130,
                hudLayout: layout
            )
        )
    }
'''
text = replace_once(text, old_layout, new_layout, "gameplay camera base helper")

text = replace_once(
    text,
    '''        let baseY = size.height * 0.5 + cameraVerticalOffset
''',
    '''        let baseY = gameplayCameraBaseY()
''',
    "runtime camera base Y",
)

path.write_text(text)
print("Integrated mobile HUD-safe gameplay framing into GameScene")
