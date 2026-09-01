from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


# 1) V23 Ranged data tuning.
stats_path = Path("Sources/EnemyArchetype.swift")
stats = stats_path.read_text()
stats = replace_once(
    stats,
'''        case .ranged:
            return EnemyStats(
                maxHP: 3,
                contactDamage: 1,
                patrolSpeed: 58,
                chaseSpeed: 92,
                detectionRange: 390,
                attackRange: 310,
                attackCooldown: 1.05,
                attackDuration: 0.34,
                hitStunDuration: 0.16,
                knockbackSpeed: 320,
                attackKind: .projectile
            )
''',
'''        case .ranged:
            return EnemyStats(
                maxHP: 3,
                contactDamage: 1,
                patrolSpeed: 58,
                chaseSpeed: 92,
                detectionRange: 340,
                attackRange: 270,
                attackCooldown: 1.45,
                attackDuration: 0.42,
                hitStunDuration: 0.16,
                knockbackSpeed: 320,
                attackKind: .projectile
            )
''',
    "ranged stats",
)
stats_path.write_text(stats)


# 2) Replace legacy Ranged AI/pending-shot behavior with the tested V23 state machine.
runtime_path = Path("Sources/MultiEnemyRuntimeInstaller.swift")
runtime = runtime_path.read_text()
runtime = replace_once(
    runtime,
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
runtime = replace_once(
    runtime,
'''                velocityX: Double(direction * 325),
''',
'''                velocityX: Double(direction * 285),
''',
    "projectile speed",
)
runtime = replace_once(
    runtime,
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
runtime = replace_once(
    runtime,
'''                if var pending = enemy.pendingShotRemaining {
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

''',
    "",
    "legacy pending shot",
)
runtime = replace_once(
    runtime,
'''                let verticalDistance = abs(player.position.y - enemy.node.position.y)
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
''',
'''                let verticalDistance = abs(player.position.y - enemy.node.position.y)

                if enemy.spawn.archetype == .ranged {
                    let delta = player.position.x - enemy.node.position.x
                    let directionToPlayer: Double = delta >= 0 ? 1 : -1
                    let horizontalDistance = abs(Double(delta))
                    let playerDetected = verticalDistance <= 95
                        && horizontalDistance <= enemy.stats.detectionRange
                    let controllerDistance = playerDetected
                        ? horizontalDistance
                        : enemy.stats.detectionRange + 1

                    let rangedOutput = enemy.rangedCombat.update(
                        dt: Double(dt),
                        distanceToPlayer: controllerDistance,
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
                        enemy.stateLabel.text = playerDetected ? "TRACK" : "IDLE"
                        enemy.attackVisual.alpha = 0
                        if playerDetected {
                            enemy.node.position.x += CGFloat(rangedOutput.movementDirection)
                                * CGFloat(enemy.stats.patrolSpeed) * dt
                        }
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
''',
    "ranged combat branch",
)
runtime_path.write_text(runtime)


# 3) Reduce Watcher Hall simultaneous pressure to one Ranged + one Grunt.
room_path = Path("Sources/RoomController.swift")
room = room_path.read_text()
room = replace_once(
    room,
'''            enemySpawns: [
                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 420, y: 130)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 930, y: 130)),
                EnemySpawn(id: 3, archetype: .grunt, position: RoomPoint(x: 690, y: 130))
            ],
''',
'''            enemySpawns: [
                EnemySpawn(id: 1, archetype: .ranged, position: RoomPoint(x: 900, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 620, y: 130))
            ],
''',
    "watcher hall composition",
)
room_path.write_text(room)

print("V23 staged patch applied: Ranged rebalance + Watcher Hall")
