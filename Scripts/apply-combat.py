#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
scene = scene_path.read_text()
if "strikeNearbyLevers" in scene:
    print("Combat already applied")
    raise SystemExit(0)

def replace_from(text, start, replacement):
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"combat missing: {start[:90]}")
    b = text.find("    private func ", a + len(start))
    if b < 0:
        raise SystemExit(f"combat missing next func after {start[:40]}")
    return text[:a] + replacement.rstrip() + "\n\n" + text[b:]

if "sprite.size = CGSize(width: 480, height: 480)" in scene:
    scene = scene.replace("sprite.size = CGSize(width: 480, height: 480)", "sprite.size = CGSize(width: 120, height: 120)", 1)

has_audio = "private let audio = GameAudio()" in scene
audio_lines = "        audio.stop(.heal)\n        audio.play(.attack)\n" if has_audio else ""

lever_state_anchor = "    private var lastAttackSequenceProcessed = 0\n"
if lever_state_anchor not in scene:
    raise SystemExit("combat missing lever state anchor")
if "leverVisualStates" not in scene:
    scene = scene.replace(lever_state_anchor, lever_state_anchor + "    private var leverVisualStates: [String: Bool] = [:]\n", 1)

start_attack = f'''    private func startAttack() {{
        guard recoveryLockRemaining <= 0 else {{ return }}
        essenceController.cancelFocus()
        cancelHealFocusFX()
        let direction: PlayerAttackDirection
        if jumpHeld && (isGrounded || velocity.dy > 80) {{
            direction = .up
        }} else if !isGrounded {{
            direction = .down
        }} else {{
            direction = .horizontal
        }}
        guard attackController.tryStart(direction: direction) else {{ return }}
        hitEnemiesThisAttack.removeAll()
        switch direction {{
        case .up: activeAttackAnimation = .attackUp
        case .down: activeAttackAnimation = .attackDown
        case .horizontal: activeAttackAnimation = .attack1
        }}
        setAnimation(activeAttackAnimation, force: true)
        attackNearbySecretWall()
        strikeNearbyLevers()
{audio_lines}    }}

    private func strikeNearbyLevers() {{
        let reach = CGRect(x: player.position.x - 90, y: player.position.y - 80, width: 180, height: 160)
        for interaction in worldLayout.interactions where (interaction.kind == .lever || interaction.kind == .shortcutLever) && interaction.rect.intersects(reach) {{
            if interactionController.activateLever(id: interaction.id) {{
                tutorialController.register(action: interaction.kind == .lever ? .lever : .shortcut)
                setLeverVisual(id: interaction.id, active: true)
                if let linked = interaction.linkedID {{ openDoorVisual(id: linked) }}
                applyInteractionVisualState()
                refreshCollisionRects()
            }}
        }}
    }}
'''
scene = replace_from(scene, "    private func startAttack() {", start_attack)

if ".filter { $0.1 <= 190 }" in scene:
    scene = scene.replace(".filter { $0.1 <= 190 }", ".filter { $0.1 <= 280 }", 1)

old_hit = "        let hitbox = CGRect(x: player.position.x + facing * 62 - 55, y: player.position.y - 42, width: 110, height: 84)\n"
new_hit = "        let spec = attackController.currentDirection.hitboxSpec(facing: Double(facing))\n        let hitbox = CGRect(x: player.position.x + CGFloat(spec.offsetX) - CGFloat(spec.width) * 0.5, y: player.position.y + CGFloat(spec.offsetY) - CGFloat(spec.height) * 0.5, width: CGFloat(spec.width), height: CGFloat(spec.height))\n"
if old_hit not in scene:
    raise SystemExit("combat missing hitbox marker")
scene = scene.replace(old_hit, new_hit, 1)

old_impact = "                showMeleeImpact(at: controller.position)\n                hitStopRemaining = max(hitStopRemaining, 0.05)\n"
new_impact = "                showMeleeImpact(at: controller.position)\n                hitStopRemaining = max(hitStopRemaining, 0.05)\n                if attackController.currentDirection == .down {\n                    velocity.dy = CGFloat(tuning.jumpVelocity) * 0.72\n                    isGrounded = false\n                }\n"
if old_impact not in scene:
    raise SystemExit("combat missing melee impact marker")
scene = scene.replace(old_impact, new_impact, 1)

door = '''    private func openDoorVisual(id: String) {
        guard let root = worldNodes[id] else { return }
        let body = root.childNode(withName: "//doorBody") ?? root
        guard body.action(forKey: "doorOpen") == nil, !body.isHidden else { return }
        let travel = (worldLayout.interactions.first(where: { $0.id == id })?.rect.height ?? 220) + 40
        let lift = SKAction.sequence([
            .group([.moveBy(x: 0, y: travel, duration: 0.38), .fadeAlpha(to: 0.05, duration: 0.38)]),
            .hide()
        ])
        lift.timingMode = .easeInEaseOut
        body.run(lift, withKey: "doorOpen")
        if let frame = root.childNode(withName: "//doorFrame"), frame.alpha > 0.01 {
            frame.run(.fadeOut(withDuration: 0.28))
        }
        refreshCollisionRects()
    }
'''
scene = replace_from(scene, "    private func openDoorVisual(id: String) {", door)

lever = '''    private func setLeverVisual(id: String, active: Bool) {
        guard let root = worldNodes[id] else { return }
        let previous = leverVisualStates[id]
        leverVisualStates[id] = active
        let justChanged = previous != nil && previous != active
        let target: CGFloat = active ? 0.72 : -0.62
        if let handle = root.childNode(withName: "//leverHandle") {
            if justChanged {
                handle.removeAction(forKey: "leverState")
                let pull = SKAction.group([
                    .moveBy(x: 0, y: -30, duration: 0.10),
                    .rotate(toAngle: target + (active ? 0.30 : -0.30), duration: 0.10)
                ])
                pull.timingMode = .easeIn
                let snap = SKAction.group([
                    .moveBy(x: 0, y: 30, duration: 0.16),
                    .rotate(toAngle: target, duration: 0.16)
                ])
                snap.timingMode = .easeOut
                handle.run(.sequence([pull, snap]), withKey: "leverState")
            } else if handle.action(forKey: "leverState") == nil, abs(handle.zRotation - target) > 0.02 {
                handle.run(.rotate(toAngle: target, duration: 0.22, shortestUnitArc: true), withKey: "leverState")
            }
        }
        if let glow = root.childNode(withName: "//leverGlow") as? SKShapeNode {
            glow.fillColor = UIColor(red: 0.45, green: 0.95, blue: 1.0, alpha: active ? 0.7 : 0)
        }
        if justChanged {
__LEVER_AUDIO__            if root.action(forKey: "leverPulse") == nil {
                root.run(.sequence([.scale(to: 1.12, duration: 0.08), .scale(to: 1, duration: 0.12)]), withKey: "leverPulse")
            }
            showLeverFlip(at: root.position)
        }
    }

    private func showLeverFlip(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 26)
        ring.position = point
        ring.strokeColor = UIColor(red: 0.55, green: 0.95, blue: 1, alpha: 0.95)
        ring.fillColor = UIColor(red: 0.55, green: 0.95, blue: 1, alpha: 0.10)
        ring.lineWidth = 4
        ring.zPosition = 60
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.1, duration: 0.28), .fadeOut(withDuration: 0.28)]),
            .removeFromParent()
        ]))
        for i in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.position = point
            spark.fillColor = .white
            spark.strokeColor = .clear
            spark.zPosition = 61
            addChild(spark)
            let angle = CGFloat(i) * .pi / 3
            spark.run(.sequence([
                .group([.moveBy(x: cos(angle) * 44, y: sin(angle) * 44, duration: 0.30), .fadeOut(withDuration: 0.30)]),
                .removeFromParent()
            ]))
        }
    }
'''
scene = replace_from(scene, "    private func setLeverVisual(id: String, active: Bool) {", lever)
if "__LEVER_AUDIO__" in scene:
    lever_audio = "            audio.play(.lever)\n" if has_audio else ""
    scene = scene.replace("__LEVER_AUDIO__", lever_audio, 1)

scene_path.write_text(scene)
print("Applied directional nail combat, pogo, lever strike, door open")
