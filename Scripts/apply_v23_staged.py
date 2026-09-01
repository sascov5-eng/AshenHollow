from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()

old = '''    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
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

new = '''    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            let oldControl = activeControls[id]
            let point = touch.location(in: skView)

            if oldControl == .focus {
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
                    activeControls[id] = .focus
                    continue
                }

                cancelFocus()
                activeControls.removeValue(forKey: id)
                continue
            }

            let newControl = classifyControl(at: point, in: skView)

            if oldControl == .jump && newControl != .jump {
                releaseJump()
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

count = text.count(old)
if count != 1:
    raise SystemExit(f"touchesMoved patch expected 1 match, found {count}")

path.write_text(text.replace(old, new, 1))
print("V23 staged patch applied: Focus touch retention")
# staged apply trigger v23 task 4
