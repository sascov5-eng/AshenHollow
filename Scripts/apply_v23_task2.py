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
'''    private enum Control {
        case left
        case right
        case focus
        case attack
        case jump
    }
''',
'''    private enum Control {
        case left
        case right
        case up
        case down
        case focus
        case attack
        case jump
    }
''',
"control enum",
)

replace_once(
'''    private var activeControls: [ObjectIdentifier: Control] = [:]
    private var attackTouchOrigins: [ObjectIdentifier: CGPoint] = [:]
    private var triggeredAttackTouches: Set<ObjectIdentifier> = []
    private var moveInput: CGFloat = 0
''',
'''    private var activeControls: [ObjectIdentifier: Control] = [:]
    private var moveInput: CGFloat = 0
''',
"input state",
)

replace_once(
'''    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let focusButton = SKShapeNode(circleOfRadius: 42)
''',
'''    private let leftButton = SKShapeNode(circleOfRadius: 40)
    private let rightButton = SKShapeNode(circleOfRadius: 40)
    private let upButton = SKShapeNode(circleOfRadius: 40)
    private let downButton = SKShapeNode(circleOfRadius: 40)
    private let focusButton = SKShapeNode(circleOfRadius: 42)
''',
"hud buttons",
)

replace_once(
'''    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let focusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
''',
'''    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let upArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let downArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let focusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
''',
"hud labels",
)

replace_once(
'''        activeControls.removeAll(keepingCapacity: true)
        attackTouchOrigins.removeAll(keepingCapacity: true)
        triggeredAttackTouches.removeAll(keepingCapacity: true)
        pendingCombatImpulses.removeAll(keepingCapacity: true)
''',
'''        activeControls.removeAll(keepingCapacity: true)
        pendingCombatImpulses.removeAll(keepingCapacity: true)
''',
"reset input",
)

replace_once(
'''        configureButton(leftButton)
        configureButton(rightButton)
        configureButton(focusButton)
''',
'''        configureButton(leftButton)
        configureButton(rightButton)
        configureButton(upButton)
        configureButton(downButton)
        configureButton(focusButton)
''',
"configure dpad",
)

replace_once(
'''        rightArrow.text = "›"
        rightArrow.fontSize = 50
        rightArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        rightArrow.verticalAlignmentMode = .center
        rightArrow.horizontalAlignmentMode = .center

        focusLabel.text = "FOCUS"
''',
'''        rightArrow.text = "›"
        rightArrow.fontSize = 50
        rightArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        rightArrow.verticalAlignmentMode = .center
        rightArrow.horizontalAlignmentMode = .center

        upArrow.text = "↑"
        upArrow.fontSize = 31
        upArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        upArrow.verticalAlignmentMode = .center
        upArrow.horizontalAlignmentMode = .center

        downArrow.text = "↓"
        downArrow.fontSize = 31
        downArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        downArrow.verticalAlignmentMode = .center
        downArrow.horizontalAlignmentMode = .center

        focusLabel.text = "FOCUS"
''',
"dpad labels",
)

replace_once(
'''        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        focusButton.addChild(focusLabel)
        attackButton.addChild(attackLabel)
        jumpButton.addChild(jumpLabel)

        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(focusButton)
        hud.addChild(attackButton)
        hud.addChild(jumpButton)
''',
'''        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        upButton.addChild(upArrow)
        downButton.addChild(downArrow)
        focusButton.addChild(focusLabel)
        attackButton.addChild(attackLabel)
        jumpButton.addChild(jumpLabel)

        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(upButton)
        hud.addChild(downButton)
        hud.addChild(focusButton)
        hud.addChild(attackButton)
        hud.addChild(jumpButton)
''',
"add dpad hud",
)

replace_once(
'''        leftButton.position = CGPoint(x: -halfW + 86, y: -halfH + bottomPadding)
        rightButton.position = CGPoint(x: -halfW + 190, y: -halfH + bottomPadding)
        focusButton.position = CGPoint(x: halfW - 318, y: -halfH + bottomPadding + 2)
''',
'''        let dpadCenterX = -halfW + 145
        let dpadCenterY = -halfH + bottomPadding
        leftButton.position = CGPoint(x: dpadCenterX - 55, y: dpadCenterY)
        rightButton.position = CGPoint(x: dpadCenterX + 55, y: dpadCenterY)
        upButton.position = CGPoint(x: dpadCenterX, y: dpadCenterY + 55)
        downButton.position = CGPoint(x: dpadCenterX, y: dpadCenterY - 55)
        focusButton.position = CGPoint(x: halfW - 318, y: -halfH + bottomPadding + 2)
''',
"dpad layout",
)

replace_once(
'''            if let control {
                activeControls[id] = control
                if control == .attack {
                    attackTouchOrigins[id] = point
                } else {
                    handleControlPressed(control)
                }
            }
''',
'''            if let control {
                activeControls[id] = control
                handleControlPressed(control)
            }
''',
"touches began",
)

old_moved = '''    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            let oldControl = activeControls[id]

            if oldControl == .attack, let origin = attackTouchOrigins[id] {
                activeControls[id] = .attack
                if !triggeredAttackTouches.contains(id) {
                    let point = touch.location(in: skView)
                    let direction = AttackGestureResolver.resolve(
                        deltaX: Double(point.x - origin.x),
                        deltaY: Double(point.y - origin.y),
                        isGrounded: isGrounded
                    )
                    if direction != .horizontal {
                        tryAttack(direction: direction)
                        triggeredAttackTouches.insert(id)
                    }
                }
                continue
            }

            let newControl = classifyControl(at: touch.location(in: skView), in: skView)

            if oldControl == .jump && newControl != .jump {
                releaseJump()
            }
            if oldControl == .focus && newControl != .focus {
                cancelFocus()
            }

            if let newControl {
                activeControls[id] = newControl
                if newControl != oldControl {
                    if newControl == .attack {
                        attackTouchOrigins[id] = touch.location(in: skView)
                    } else {
                        handleControlPressed(newControl)
                    }
                }
            } else {
                activeControls.removeValue(forKey: id)
            }
        }

        recalculateMoveInput()
        refreshButtonVisuals()
    }
'''
new_moved = '''    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            let oldControl = activeControls[id]
            let newControl = classifyControl(at: touch.location(in: skView), in: skView)

            if oldControl == .jump && newControl != .jump {
                releaseJump()
            }
            if oldControl == .focus && newControl != .focus {
                cancelFocus()
            }

            if let newControl {
                activeControls[id] = newControl
                if newControl != oldControl {
                    handleControlPressed(newControl)
                }
            } else {
                activeControls.removeValue(forKey: id)
            }
        }

        recalculateMoveInput()
        refreshButtonVisuals()
    }
'''
replace_once(old_moved, new_moved, "touches moved")

replace_once(
'''            switch activeControls[id] {
            case .jump:
                releaseJump()
            case .attack:
                if !triggeredAttackTouches.contains(id) {
                    tryAttack(direction: .horizontal)
                }
            case .focus:
                cancelFocus()
            case .left, .right, .none:
                break
            }

            activeControls.removeValue(forKey: id)
            attackTouchOrigins.removeValue(forKey: id)
            triggeredAttackTouches.remove(id)
''',
'''            switch activeControls[id] {
            case .jump:
                releaseJump()
            case .focus:
                cancelFocus()
            case .left, .right, .up, .down, .attack, .none:
                break
            }

            activeControls.removeValue(forKey: id)
''',
"release touches",
)

replace_once(
'''    private func handleControlPressed(_ control: Control) {
        switch control {
        case .jump:
            queueJump()
        case .focus:
            beginFocus()
        case .attack:
            break
        case .left, .right:
            break
        }
    }
''',
'''    private func handleControlPressed(_ control: Control) {
        switch control {
        case .jump:
            queueJump()
        case .focus:
            beginFocus()
        case .attack:
            let direction = DPadAttackDirectionResolver.resolve(
                upHeld: activeControls.values.contains(.up),
                downHeld: activeControls.values.contains(.down),
                isGrounded: isGrounded
            )
            tryAttack(direction: direction)
        case .left, .right, .up, .down:
            break
        }
    }
''',
"handle pressed",
)

replace_once(
'''        let controlY = height * 0.80
        let candidates: [(control: Control, center: CGPoint, radius: CGFloat)] = [
            (.left, CGPoint(x: width * 0.10, y: controlY), 70),
            (.right, CGPoint(x: width * 0.225, y: controlY), 70),
            (.focus, CGPoint(x: width * 0.62, y: controlY), 56),
            (.attack, CGPoint(x: width * 0.76, y: controlY), 60),
            (.jump, CGPoint(x: width * 0.90, y: controlY), 64)
        ]
''',
'''        let dpadX = width * 0.17
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
''',
"classify controls",
)

replace_once(
'''    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: activeControls.values.contains(.left))
        animateButton(rightButton, pressed: activeControls.values.contains(.right))
        animateButton(focusButton, pressed: activeControls.values.contains(.focus))
        animateButton(attackButton, pressed: activeControls.values.contains(.attack))
        animateButton(jumpButton, pressed: activeControls.values.contains(.jump))
    }
''',
'''    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: activeControls.values.contains(.left))
        animateButton(rightButton, pressed: activeControls.values.contains(.right))
        animateButton(upButton, pressed: activeControls.values.contains(.up))
        animateButton(downButton, pressed: activeControls.values.contains(.down))
        animateButton(focusButton, pressed: activeControls.values.contains(.focus))
        animateButton(attackButton, pressed: activeControls.values.contains(.attack))
        animateButton(jumpButton, pressed: activeControls.values.contains(.jump))
    }
''',
"button visuals",
)

path.write_text(text)
print("V23 Task 2 patch applied")
