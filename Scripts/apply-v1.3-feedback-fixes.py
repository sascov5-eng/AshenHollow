from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()

replacements = [
    ("    private var useSecondAttack = false\n", ""),
    ("    private let cameraZoom: CGFloat = 1.28", "    private let cameraZoom: CGFloat = 1.75"),
    ("            sprite.position = CGPoint(x: 0, y: 12)", "            sprite.position = CGPoint(x: 0, y: -8)"),
]
for old, new in replacements:
    if old not in text:
        raise SystemExit(f"v1.3 anchor not found: {old.strip()}")
    text = text.replace(old, new, 1)

start = text.index("    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {")
end = text.index("    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {")
new_touches = '''    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)

            if isInside(point, button: leftButton, radius: 60) {
                leftTouches.insert(id)
                animateButton(leftButton, pressed: true)
            } else if isInside(point, button: rightButton, radius: 60) {
                rightTouches.insert(id)
                animateButton(rightButton, pressed: true)
            } else if isInside(point, button: attackButton, radius: 48) {
                startAttack()
                pulse(attackButton)
            } else if isInside(point, button: dashButton, radius: 48) {
                startDash()
                pulse(dashButton)
            } else if isInside(point, button: healButton, radius: 44) {
                startHeal()
                pulse(healButton)
            } else if isInside(point, button: jumpButton, radius: 55) {
                jumpTouches.insert(id)
                jumpHeld = true
                jumpBufferTimer = tuning.jumpBufferDuration
                tryConsumeJump()
                animateButton(jumpButton, pressed: true)
            }
        }

        updateInputTarget()
    }

'''
text = text[:start] + new_touches + text[end:]

attack_start = text.index("    private func startAttack() {")
attack_end = text.index("    private func startHeal() {")
new_attack = '''    private func startAttack() {
        essenceController.cancelFocus()
        guard attackController.tryStart(direction: .horizontal) else { return }

        activeAttackAnimation = .attack1
        setAnimation(.attack1, force: true)
    }

'''
text = text[:attack_start] + new_attack + text[attack_end:]

path.write_text(text)
print("APPLIED v1.3 CAMERA + GROUND + ATTACK + CONTROL FIXES")
