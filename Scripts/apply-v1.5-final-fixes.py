#!/usr/bin/env python3
from pathlib import Path

p = Path("Sources/GameSceneV14.swift")
s = p.read_text(encoding="utf-8")


def need(old: str, new: str) -> None:
    global s
    if old not in s:
        raise SystemExit(f"v1.5 final fix marker missing: {old[:100]!r}")
    s = s.replace(old, new, 1)

need(
    "    private var enemyHealthBars: [String: EnemyHealthBarNode] = [:]\n",
    "    private var enemyHealthBars: [String: EnemyHealthBarNode] = [:]\n    private var hitEnemiesThisAttack = Set<String>()\n    private weak var activeTutorialButton: SKShapeNode?\n"
)

need(
'''        guard attackController.tryStart(direction: .horizontal) else { return }
        activeAttackAnimation = .attack1
''',
'''        guard attackController.tryStart(direction: .horizontal) else { return }
        hitEnemiesThisAttack.removeAll()
        activeAttackAnimation = .attack1
''')

start = s.find("    private func processAttackHits() {")
end = s.find("    private func updateTutorial()", start)
if start < 0 or end < 0:
    raise SystemExit("processAttackHits block missing")
s = s[:start] + '''    private func processAttackHits() {
        guard attackController.isHitboxActive else { return }
        let hitbox = CGRect(x: player.position.x + facing * 62 - 55, y: player.position.y - 42, width: 110, height: 84)
        for (id, controller) in enemyControllers where controller.isAlive {
            guard !hitEnemiesThisAttack.contains(id) else { continue }
            guard let node = enemyNodes[id], hitbox.intersects(node.calculateAccumulatedFrame()) else { continue }
            hitEnemiesThisAttack.insert(id)
            if controller.receiveMeleeHit() {
                essenceController.gainFromAcceptedMeleeHit()
                session.enemyStates[id] = controller.snapshot()
                if let spec = worldLayout.enemies.first(where: { $0.id == id }) {
                    enemyHealthBars[id]?.updateHealthBar(current: controller.hp, max: spec.maxHP)
                }
                node.run(SKAction.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeAlpha(to: 1, duration: 0.08)]))
            }
        }
    }

''' + s[end:]

start = s.find("    private func updateTutorial() {")
end = s.find("    private func movePlayer", start)
if start < 0 or end < 0:
    raise SystemExit("tutorial highlight block missing")
s = s[:start] + '''    private func updateTutorial() {
        tutorialController.update(playerPosition: player.position)
        guard let presentation = tutorialController.presentation else {
            tutorialLabel.text = ""
            clearTutorialButtonHighlights()
            return
        }
        tutorialLabel.text = presentation.text
        switch presentation.target {
        case .hud(let id):
            switch id {
            case "JUMP": pulseTutorial(jumpButton)
            case "DASH": pulseTutorial(dashButton)
            case "ATK": pulseTutorial(attackButton)
            case "HEAL": pulseTutorial(healButton)
            case "ACTION": pulseTutorial(actionButton)
            case "MOVE": pulseTutorial(rightButton)
            default: clearTutorialButtonHighlights()
            }
        case .world(let id):
            clearTutorialButtonHighlights()
            if worldNodes[id]?.action(forKey: "tutorialPulse") == nil {
                worldNodes[id]?.run(SKAction.repeatForever(SKAction.sequence([.fadeAlpha(to: 0.5, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)])), withKey: "tutorialPulse")
            }
        case .none:
            clearTutorialButtonHighlights()
        }
    }

    private func pulseTutorial(_ button: SKShapeNode) {
        if activeTutorialButton !== button {
            clearTutorialButtonHighlights()
            activeTutorialButton = button
        }
        button.strokeColor = .yellow
        button.lineWidth = 5
        if button.action(forKey: "tutorialPulse") == nil {
            button.run(SKAction.repeatForever(SKAction.sequence([.scale(to: 1.10, duration: 0.28), .scale(to: 1.0, duration: 0.28)])), withKey: "tutorialPulse")
        }
        tutorialArrow.isHidden = false
        tutorialArrow.position = CGPoint(x: button.position.x, y: button.position.y + 72)
        if tutorialArrow.action(forKey: "tutorialArrowPulse") == nil {
            tutorialArrow.run(SKAction.repeatForever(SKAction.sequence([.moveBy(x: 0, y: -8, duration: 0.28), .moveBy(x: 0, y: 8, duration: 0.28)])), withKey: "tutorialArrowPulse")
        }
    }

    private func clearTutorialButtonHighlights() {
        tutorialArrow.removeAction(forKey: "tutorialArrowPulse")
        tutorialArrow.isHidden = true
        for b in [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton, actionButton] {
            b.removeAction(forKey: "tutorialPulse")
            b.setScale(1)
            b.strokeColor = UIColor(white: 1, alpha: 0.16)
            b.lineWidth = 2
            if b.alpha < 0.4 { b.alpha = 1 }
        }
        activeTutorialButton = nil
    }

''' + s[end:]

need(
    "let riding = MovingPlatformRideSupport.isRiding(playerFrame: playerFrameBefore, platformFrame: oldFrame, grounded: isGrounded)",
    "let riding = MovingPlatformRideSupport.isRiding(playerFrame: playerFrameBefore, platformFrame: oldFrame, grounded: isGrounded || isStandingOnSurface(), tolerance: 10)"
)

p.write_text(s, encoding="utf-8")
print("Applied v1.5 final stability fixes")
