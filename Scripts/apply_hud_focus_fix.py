from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    text = text.replace(old, new, 1)


replace_once(
'''    private let leftButton = SKShapeNode(circleOfRadius: 40)
    private let rightButton = SKShapeNode(circleOfRadius: 40)
    private let upButton = SKShapeNode(circleOfRadius: 40)
    private let downButton = SKShapeNode(circleOfRadius: 40)
''',
'''    private let leftButton = SKShapeNode(circleOfRadius: 32)
    private let rightButton = SKShapeNode(circleOfRadius: 32)
    private let upButton = SKShapeNode(circleOfRadius: 32)
    private let downButton = SKShapeNode(circleOfRadius: 32)
''',
"dpad visual radii",
)

replace_once(
'''    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }

        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let bottomPadding = max(76, size.height * 0.15)

        let dpadCenterX = -halfW + 145
        let dpadCenterY = -halfH + bottomPadding
        leftButton.position = CGPoint(x: dpadCenterX - 55, y: dpadCenterY)
        rightButton.position = CGPoint(x: dpadCenterX + 55, y: dpadCenterY)
        upButton.position = CGPoint(x: dpadCenterX, y: dpadCenterY + 55)
        downButton.position = CGPoint(x: dpadCenterX, y: dpadCenterY - 55)
        focusButton.position = CGPoint(x: halfW - 318, y: -halfH + bottomPadding + 2)
        attackButton.position = CGPoint(x: halfW - 205, y: -halfH + bottomPadding + 2)
        jumpButton.position = CGPoint(x: halfW - 88, y: -halfH + bottomPadding + 4)
    }
''',
'''    private func currentHUDLayout(in skView: SKView? = nil) -> HUDControlLayout {
        let viewWidth = Double(skView?.bounds.width ?? size.width)
        let viewHeight = Double(skView?.bounds.height ?? size.height)
        let safeBottom = Double(skView?.safeAreaInsets.bottom ?? view?.safeAreaInsets.bottom ?? 0)
        return HUDControlLayout(
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            safeBottomInset: safeBottom
        )
    }

    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }

        let layout = currentHUDLayout(in: view)
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5

        func position(_ button: SKShapeNode, as kind: HUDControlKind) {
            let target = layout.target(for: kind)
            button.position = CGPoint(
                x: CGFloat(target.center.x) - halfW,
                y: halfH - CGFloat(target.center.y)
            )
        }

        position(leftButton, as: .left)
        position(rightButton, as: .right)
        position(upButton, as: .up)
        position(downButton, as: .down)
        position(focusButton, as: .focus)
        position(attackButton, as: .attack)
        position(jumpButton, as: .jump)
    }
''',
"shared HUD visual layout",
)

replace_once(
'''            if oldControl == .focus {
                let focusCenter = CGPoint(
                    x: skView.bounds.width * 0.62,
                    y: skView.bounds.height * 0.80
                )
                let distance = hypot(
                    point.x - focusCenter.x,
                    point.y - focusCenter.y
                )
                if TouchRetentionPolicy.shouldRetain(
                    distanceFromCenter: Double(distance),
                    baseRadius: 56
                ) {
''',
'''            if oldControl == .focus {
                let focusTarget = currentHUDLayout(in: skView).target(for: .focus)
                let focusCenter = CGPoint(
                    x: CGFloat(focusTarget.center.x),
                    y: CGFloat(focusTarget.center.y)
                )
                let distance = hypot(
                    point.x - focusCenter.x,
                    point.y - focusCenter.y
                )
                if TouchRetentionPolicy.shouldRetain(
                    distanceFromCenter: Double(distance),
                    baseRadius: focusTarget.hitRadius
                ) {
''',
"focus retention uses visible center",
)

replace_once(
'''    private func classifyControl(at point: CGPoint, in skView: SKView) -> Control? {
        let width = skView.bounds.width
        let height = skView.bounds.height
        guard width > 0, height > 0 else { return nil }

        let dpadX = width * 0.17
        let dpadY = height * 0.80
        let dpadStep = min(width, height) * 0.075
        let candidates: [(control: Control, center: CGPoint, radius: CGFloat)] = [
            (.left, CGPoint(x: dpadX - dpadStep, y: dpadY), 54),
            (.right, CGPoint(x: dpadX + dpadStep, y: dpadY), 54),
            (.up, CGPoint(x: dpadX, y: dpadY - dpadStep), 54),
            (.down, CGPoint(x: dpadX, y: dpadY + dpadStep), 54),
            (.focus, CGPoint(x: width * 0.62, y: dpadY), 56),
            (.attack, CGPoint(x: width * 0.76, y: dpadY), 60),
            (.jump, CGPoint(x: width * 0.90, y: dpadY), 64)
        ]

        var best: (control: Control, distance: CGFloat)?

        for candidate in candidates {
            let distance = hypot(point.x - candidate.center.x, point.y - candidate.center.y)
            guard distance <= candidate.radius else { continue }

            if best == nil || distance < best!.distance {
                best = (candidate.control, distance)
            }
        }

        return best?.control
    }
''',
'''    private func classifyControl(at point: CGPoint, in skView: SKView) -> Control? {
        guard let kind = currentHUDLayout(in: skView).resolve(
            x: Double(point.x),
            y: Double(point.y)
        ) else {
            return nil
        }

        switch kind {
        case .left: return .left
        case .right: return .right
        case .up: return .up
        case .down: return .down
        case .focus: return .focus
        case .attack: return .attack
        case .jump: return .jump
        }
    }
''',
"touch classification uses shared HUD layout",
)

path.write_text(text)
print("HUD/Focus staged patch applied")
# trigger HUD/Focus staged verification
