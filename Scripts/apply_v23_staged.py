from pathlib import Path

path = Path("Sources/MultiEnemyRuntimeInstaller.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    text = text.replace(old, new, 1)


replace_once(
'''    var model: EnemyRuntimeModel
    var ai: EnemyAIController
    var attackElapsed: TimeInterval?
    var currentAttackID: Int = 0
    var lastDamageAttackID: Int = -1
    var pendingShotRemaining: TimeInterval?
    var contactCooldown: TimeInterval = 0
''',
'''    var model: EnemyRuntimeModel
    var ai: EnemyAIController
    var rangedCombat = RangedCombatController()
    var attackElapsed: TimeInterval?
    var currentAttackID: Int = 0
    var lastDamageAttackID: Int = -1
    var contactCooldown: TimeInterval = 0
''',
"live ranged controller",
)

replace_once(
'''                velocityX: Double(direction * 325),
''',
'''                velocityX: Double(direction * 285),
''',
"projectile speed",
)

replace_once(
'''                    if accepted {
                        enemy.attackElapsed = nil
                        enemy.pendingShotRemaining = nil
                        enemy.attackVisual.alpha = 0
''',
'''                    if accepted {
                        enemy.attackElapsed = nil
                        if enemy.spawn.archetype == .ranged {
                            enemy.rangedCombat = RangedCombatController()
                        }
                        enemy.model.markAttackDamageWindowActive(false)
                        enemy.attackVisual.alpha = 0
''',
"hit reaction resets ranged aim",
)

pending_block = '''                if var pending = enemy.pendingShotRemaining {
                    pending -= Double(dt)
                    enemy.pendingShotRemaining = pending
                    enemy.stateLabel.text = "AIM"
                    enemy.attackVisual.alpha = 0.45
                    if pending <= 0 {
                        enemy.pendingShotRemaining = nil
                        enemy.attackVisual.alpha = 0
                        let direction: CGFloat = player.position.x >= enemy.node.position.x ? 1 : -1
                        spawnProjectile(from: enemy, direction: direction)
                    }
                    continue
                }

'''
replace_once(pending_block, "", "legacy pending shot")

old_combat = '''                let verticalDistance = abs(player.position.y - enemy.node.position.y)
                let sensedPlayerX: CGFloat = verticalDistance <= 95
                    ? player.position.x
                    : enemy.node.position.x + 1000

                let output = enemy.ai.update(
                    dt: Double(dt),
                    enemyX: Double(enemy.node.position.x),
                    playerX: Double(sensedPlayerX)
                )

                let facing: CGFloat = output.facing >= 0 ? 1 : -1
                enemy.attackVisual.position.x = facing * attackVisualOffset(for: enemy.spawn.archetype)
                enemy.currentAttackID = output.attackID

                if enemy.spawn.archetype == .ranged {
                    let distance = abs(player.position.x - enemy.node.position.x)
                    if output.startedAttack {
                        enemy.pendingShotRemaining = 0.18
                        enemy.stateLabel.text = "AIM"
                        enemy.attackVisual.alpha = 0.45
                    } else if distance < 145 {
                        let away: CGFloat = player.position.x >= enemy.node.position.x ? -1 : 1
                        enemy.node.position.x += away * CGFloat(enemy.stats.chaseSpeed * 0.72) * dt
                        enemy.stateLabel.text = "EVADE"
                    } else {
                        enemy.node.position.x += CGFloat(output.moveDirection) * CGFloat(speed(for: output.state, enemy: enemy)) * dt
                        enemy.stateLabel.text = output.state.rawValue.uppercased()
                    }
                    enemy.node.position.x = max(
                        physicalOriginX + 28,
                        min(physicalOriginX + roomWidth - 28, enemy.node.position.x)
                    )
                    continue
                }
'''

new_combat = '''                let verticalDistance = abs(player.position.y - enemy.node.position.y)
                let sensedPlayerX: CGFloat = verticalDistance <= 95
                    ? player.position.x
                    : enemy.node.position.x + 1000

                if enemy.spawn.archetype == .ranged {
                    let delta = player.position.x - enemy.node.position.x
                    let directionToPlayer: Double = delta >= 0 ? 1 : -1
                    let distanceToPlayer: Double = verticalDistance <= 95
                        ? abs(Double(delta))
                        : 1000
                    let rangedOutput = enemy.rangedCombat.update(
                        dt: Double(dt),
                        distanceToPlayer: distanceToPlayer,
                        directionToPlayer: directionToPlayer
                    )
                    let rangedFacing: CGFloat = directionToPlayer >= 0 ? 1 : -1
                    enemy.attackVisual.position.x = rangedFacing * attackVisualOffset(for: .ranged)

                    switch rangedOutput.state {
                    case .aiming:
                        enemy.stateLabel.text = "AIM"
                        enemy.attackVisual.alpha = 0.70
                    case .recovery:
                        enemy.stateLabel.text = "RECOVER"
                        enemy.attackVisual.alpha = 0.16
                    case .retreating:
                        enemy.stateLabel.text = "EVADE"
                        enemy.attackVisual.alpha = 0
                        enemy.node.position.x += CGFloat(rangedOutput.movementDirection)
                            * CGFloat(enemy.stats.chaseSpeed * 0.72) * dt
                    case .tracking:
                        enemy.stateLabel.text = "TRACK"
                        enemy.attackVisual.alpha = 0
                        enemy.node.position.x += CGFloat(rangedOutput.movementDirection)
                            * CGFloat(enemy.stats.patrolSpeed) * dt
                    }

                    if rangedOutput.shouldFire {
                        spawnProjectile(from: enemy, direction: rangedFacing)
                    }

                    enemy.node.position.x = max(
                        physicalOriginX + 28,
                        min(physicalOriginX + roomWidth - 28, enemy.node.position.x)
                    )
                    continue
                }

                let output = enemy.ai.update(
                    dt: Double(dt),
                    enemyX: Double(enemy.node.position.x),
                    playerX: Double(sensedPlayerX)
                )

                let facing: CGFloat = output.facing >= 0 ? 1 : -1
                enemy.attackVisual.position.x = facing * attackVisualOffset(for: enemy.spawn.archetype)
                enemy.currentAttackID = output.attackID
'''
replace_once(old_combat, new_combat, "ranged combat branch")

path.write_text(text)
print("V23 staged patch applied: Ranged runtime integration")
