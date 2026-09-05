#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
view_path = Path("Sources/GameView.swift")
plist_path = Path("Info.plist")
scene = scene_path.read_text(encoding="utf-8")


def replace_block(text: str, start: str, end: str, replacement: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"missing start marker: {start!r}")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"missing end marker: {end!r}")
    return text[:a] + replacement.rstrip() + "\n\n" + text[b:]

scene = scene.replace("private var movingNodes: [String: SKShapeNode] = [:]", "private var movingNodes: [String: SKNode] = [:]")
scene = scene.replace("private var enemyNodes: [String: SKShapeNode] = [:]", "private var enemyNodes: [String: SKNode] = [:]\n    private var enemyHealthBars: [String: EnemyHealthBarNode] = [:]")
scene = scene.replace(
    "    private let healButton = SKShapeNode(circleOfRadius: 40)\n",
    "    private let healButton = SKShapeNode(circleOfRadius: 40)\n    private let actionButton = SKShapeNode(circleOfRadius: 42)\n"
)
scene = scene.replace(
    "    private let healLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n",
    "    private let healLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n    private let actionLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n    private let tutorialArrow = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n"
)

build_world = r'''    private func buildWorld() {
        staticPlatformRects = worldLayout.collisionRects

        let backdrop = SKShapeNode(rectOf: worldLayout.worldBounds.size)
        backdrop.fillColor = UIColor(red: 0.018, green: 0.022, blue: 0.035, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldLayout.worldBounds.midX, y: worldLayout.worldBounds.midY)
        backdrop.zPosition = -125
        addChild(backdrop)
        PixelCaveArt.addParallax(to: self, worldBounds: worldLayout.worldBounds)

        for rect in staticPlatformRects {
            let node = PixelCaveArt.terrainNode(rect: rect)
            node.zPosition = 1
            addChild(node)
        }

        for hazard in worldLayout.hazards {
            switch hazard.kind {
            case .spikes:
                let node = PixelCaveArt.spikeNode(rect: hazard.rect)
                node.zPosition = 12
                addChild(node)
                worldNodes[hazard.id] = node
                addWorldCaption("ШИПЫ", at: CGPoint(x: hazard.rect.midX, y: hazard.rect.maxY + 48), color: .systemRed)
            case .deathZone:
                let node = SKShapeNode(rectOf: hazard.rect.size)
                node.fillColor = UIColor.black.withAlphaComponent(0.5)
                node.strokeColor = UIColor.systemRed.withAlphaComponent(0.75)
                node.lineWidth = 3
                node.position = CGPoint(x: hazard.rect.midX, y: hazard.rect.midY)
                node.zPosition = -4
                addChild(node)
                worldNodes[hazard.id] = node
                addWorldCaption("ЯМА — СМЕРТЬ", at: CGPoint(x: hazard.rect.midX, y: hazard.rect.maxY - 35), color: .systemRed)
            }
        }

        for checkpoint in worldLayout.checkpoints {
            let node = PixelCaveArt.checkpointNode(active: session.activeCheckpointID == checkpoint.id)
            node.position = CGPoint(x: checkpoint.position.x, y: 145)
            node.zPosition = 20
            addChild(node)
            worldNodes[checkpoint.id] = node
            addWorldCaption("КОНТРОЛЬНАЯ ТОЧКА", at: CGPoint(x: checkpoint.position.x, y: 215), color: .cyan)
        }

        for spec in worldLayout.movingPlatforms {
            let controller = MovingPlatformController(spec: spec)
            movingControllers[spec.id] = controller
            let node = PixelCaveArt.movingPlatformNode(size: spec.size, horizontal: spec.axis == .horizontal)
            node.position = spec.start
            node.zPosition = 10
            addChild(node)
            movingNodes[spec.id] = node
            worldNodes[spec.id] = node
        }

        for interaction in worldLayout.interactions {
            let node = PixelCaveArt.interactionNode(kind: interaction.kind, rect: interaction.rect)
            node.position = CGPoint(x: interaction.rect.midX, y: interaction.rect.midY)
            node.zPosition = 18
            addChild(node)
            worldNodes[interaction.id] = node
            switch interaction.kind {
            case .lever: addWorldCaption("РЫЧАГ", at: CGPoint(x: interaction.rect.midX, y: interaction.rect.maxY + 35), color: .systemYellow)
            case .shortcutLever: addWorldCaption("РЫЧАГ КОРОТКОГО ПУТИ", at: CGPoint(x: interaction.rect.midX, y: interaction.rect.maxY + 35), color: .systemYellow)
            case .door, .shortcutDoor: addWorldCaption("ДВЕРЬ", at: CGPoint(x: interaction.rect.midX, y: interaction.rect.maxY + 35), color: .white)
            case .breakableWall: addWorldCaption("СЕКРЕТНАЯ СТЕНА", at: CGPoint(x: interaction.rect.midX, y: interaction.rect.maxY + 35), color: .systemOrange)
            case .hiddenPassage: addWorldCaption("СКРЫТЫЙ ПРОХОД", at: CGPoint(x: interaction.rect.midX, y: interaction.rect.maxY + 35), color: .cyan)
            }
        }

        let exit = PixelCaveArt.exitNode()
        exit.position = CGPoint(x: worldLayout.exitMarker.midX, y: worldLayout.exitMarker.midY)
        exit.zPosition = 15
        addChild(exit)
        worldNodes["exit"] = exit
        addWorldCaption("ТЕСТОВАЯ ЗОНА ПРОЙДЕНА", at: CGPoint(x: worldLayout.exitMarker.midX, y: worldLayout.exitMarker.maxY + 55), color: .cyan)
    }'''
scene = replace_block(scene, "    private func buildWorld() {", "    @discardableResult\n    private func addBlock", build_world)

build_enemies = r'''    private func buildEnemies() {
        for spec in worldLayout.enemies {
            let controller = TestEnemyController(spec: spec)
            enemyControllers[spec.id] = controller
            let node = PixelCaveArt.enemyNode(kind: spec.kind)
            node.position = spec.spawn
            node.zPosition = 42
            let bar = EnemyHealthBarNode()
            bar.position = CGPoint(x: 0, y: 72)
            bar.zPosition = 10
            bar.updateHealthBar(current: controller.hp, max: spec.maxHP)
            node.addChild(bar)
            addChild(node)
            enemyNodes[spec.id] = node
            enemyHealthBars[spec.id] = bar
        }
    }'''
scene = replace_block(scene, "    private func buildEnemies() {", "    private func initializeEnemySessionState", build_enemies)

build_hud = r'''    private func buildHUD() {
        hud.removeFromParent()
        hud.removeAllChildren()
        gameCamera.addChild(hud)
        hud.zPosition = 1000

        [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton, actionButton].forEach(configureButton)
        configureLabel(leftArrow, text: "‹", size: 50)
        configureLabel(rightArrow, text: "›", size: 50)
        configureLabel(jumpLabel, text: "ПРЫЖОК", size: 10)
        configureLabel(attackLabel, text: "АТАКА", size: 11)
        configureLabel(dashLabel, text: "РЫВОК", size: 10)
        configureLabel(healLabel, text: "ЛЕЧЕНИЕ", size: 9)
        configureLabel(actionLabel, text: "ДЕЙСТВИЕ", size: 8)
        configureLabel(statusLabel, text: "", size: 11)
        configureLabel(tutorialLabel, text: "", size: 17)
        configureLabel(tutorialArrow, text: "↓", size: 28)
        tutorialLabel.fontColor = .yellow
        tutorialArrow.fontColor = .yellow
        tutorialArrow.isHidden = true

        leftButton.addChild(leftArrow); rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel); attackButton.addChild(attackLabel)
        dashButton.addChild(dashLabel); healButton.addChild(healLabel); actionButton.addChild(actionLabel)
        [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton, actionButton, statusLabel, tutorialLabel, tutorialArrow].forEach { hud.addChild($0) }

        recoveryOverlay.fillColor = .black
        recoveryOverlay.strokeColor = .clear
        recoveryOverlay.alpha = 0
        recoveryOverlay.zPosition = 2000
        recoveryOverlay.path = CGPath(rect: CGRect(x: -size.width, y: -size.height, width: size.width * 2, height: size.height * 2), transform: nil)
        hud.addChild(recoveryOverlay)
        updateHUDStatus()
    }'''
scene = replace_block(scene, "    private func buildHUD() {", "    private func configureButton", build_hud)

layout_hud = r'''    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let bottom = max(72, size.height * 0.14)
        leftButton.position = CGPoint(x: -halfW + 82, y: -halfH + bottom)
        rightButton.position = CGPoint(x: -halfW + 182, y: -halfH + bottom)
        jumpButton.position = CGPoint(x: halfW - 82, y: -halfH + bottom + 4)
        attackButton.position = CGPoint(x: halfW - 182, y: -halfH + bottom + 24)
        dashButton.position = CGPoint(x: halfW - 82, y: -halfH + bottom + 108)
        healButton.position = CGPoint(x: halfW - 182, y: -halfH + bottom + 116)
        actionButton.position = CGPoint(x: halfW - 284, y: -halfH + bottom + 74)
        statusLabel.position = CGPoint(x: halfW - 175, y: halfH - 58)
        tutorialLabel.position = CGPoint(x: 0, y: halfH - 105)
    }'''
scene = replace_block(scene, "    private func layoutHUD() {", "    override func touchesBegan", layout_hud)

scene = scene.replace(
'''            } else if isInside(point, button: healButton, radius: 44) {
                startHeal(); pulse(healButton); tutorialController.register(action: .heal)
            } else if isInside(point, button: jumpButton, radius: 55) {''',
'''            } else if isInside(point, button: healButton, radius: 44) {
                startHeal(); pulse(healButton); tutorialController.register(action: .heal)
            } else if isInside(point, button: actionButton, radius: 48) {
                startAction(); pulse(actionButton)
            } else if isInside(point, button: jumpButton, radius: 55) {''')

combat_actions = r'''    private func startAttack() {
        guard recoveryLockRemaining <= 0 else { return }
        essenceController.cancelFocus()
        guard attackController.tryStart(direction: .horizontal) else { return }
        activeAttackAnimation = .attack1
        setAnimation(.attack1, force: true)
        attackNearbySecretWall()
    }

    private func startHeal() {
        guard recoveryLockRemaining <= 0, essenceController.beginFocus(currentHP: currentHP, maxHP: maxHP) else { return }
        velocity.dx = 0
        let glow = SKAction.sequence([SKAction.fadeAlpha(to: 0.45, duration: 0.15), SKAction.fadeAlpha(to: 1, duration: 0.15)])
        playerVisual.run(SKAction.repeat(glow, count: 3), withKey: "heal")
    }

    private func startAction() {
        guard recoveryLockRemaining <= 0 else { return }
        activateNearbyAction()
    }

    private func activateNearbyAction() {
        for cp in worldLayout.checkpoints where hypot(player.position.x - cp.position.x, player.position.y - cp.position.y) < 110 {
            let state = PlayerResourceState(hp: currentHP, maxHP: maxHP, light: essenceController.essence)
            if let result = CheckpointController.activate(id: cp.id, playerState: state, session: session, layout: worldLayout) {
                currentHP = result.player.hp
                worldNodes[cp.id]?.alpha = 1
                worldNodes[cp.id]?.run(SKAction.repeat(SKAction.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.12)]), count: 2))
                tutorialController.register(action: .checkpoint)
                return
            }
        }

        let probe = CGRect(x: player.position.x + facing * 50 - 55, y: player.position.y - 60, width: 110, height: 125)
        for interaction in worldLayout.interactions where interaction.rect.intersects(probe) {
            if interaction.kind == .lever || interaction.kind == .shortcutLever {
                if interactionController.activateLever(id: interaction.id) {
                    tutorialController.register(action: interaction.kind == .lever ? .lever : .shortcut)
                    applyInteractionVisualState()
                    refreshCollisionRects()
                    return
                }
            }
        }
    }

    private func attackNearbySecretWall() {
        let probe = CGRect(x: player.position.x + facing * 50 - 45, y: player.position.y - 55, width: 90, height: 110)
        for interaction in worldLayout.interactions where interaction.kind == .breakableWall && interaction.rect.intersects(probe) {
            if interactionController.attackSecretWall(id: interaction.id) { tutorialController.register(action: .secretWall) }
        }
        applyInteractionVisualState()
        refreshCollisionRects()
    }'''
scene = replace_block(scene, "    private func startAttack() {", "    private func updateMovingPlatforms", combat_actions)

moving = r'''    private func updateMovingPlatforms(_ dt: TimeInterval) {
        let playerFrameBefore = playerColliderFrame()
        for (id, controller) in movingControllers {
            let oldFrame = controller.frame
            let riding = MovingPlatformRideSupport.isRiding(playerFrame: playerFrameBefore, platformFrame: oldFrame, grounded: isGrounded)
            let delta = controller.update(dt: dt)
            movingNodes[id]?.position = controller.state.position
            if riding {
                player.position = MovingPlatformRideSupport.applyPlatformDelta(delta, to: player.position)
                isGrounded = true
                coyoteTimer = tuning.coyoteDuration
                tutorialController.register(action: controller.spec.axis == .horizontal ? .movingPlatformHorizontal : .movingPlatformVertical)
            }
        }
    }'''
scene = replace_block(scene, "    private func updateMovingPlatforms(_ dt: TimeInterval) {", "    private func refreshCollisionRects", moving)

checkpoints = r'''    private func updateCheckpoints() {
        for cp in worldLayout.checkpoints {
            let active = session.activeCheckpointID == cp.id
            worldNodes[cp.id]?.alpha = active ? 1 : 0.65
        }
    }'''
scene = replace_block(scene, "    private func updateCheckpoints() {", "    private func updateInteractions", checkpoints)

update_enemies = r'''    private func updateEnemies(_ dt: TimeInterval) {
        guard recoveryLockRemaining <= 0 else { return }
        for spec in worldLayout.enemies {
            guard let controller = enemyControllers[spec.id], let node = enemyNodes[spec.id] else { continue }
            let result = controller.update(dt: dt, playerPosition: player.position)
            node.position = result.position
            node.isHidden = !controller.isAlive
            enemyHealthBars[spec.id]?.updateHealthBar(current: controller.hp, max: spec.maxHP)
            session.enemyStates[spec.id] = controller.snapshot()
            guard controller.isAlive else { continue }
            let enemyFrame = node.calculateAccumulatedFrame().insetBy(dx: -3, dy: -3)
            if enemyFrame.intersects(playerColliderFrame()), let hit = damageController.takeHit(from: controller.position.x, playerX: player.position.x) {
                essenceController.cancelFocus()
                currentHP = max(0, currentHP - hit.hpLoss)
                velocity = hit.knockback
                lifeController.registerDamage(isLethal: currentHP == 0)
                if currentHP == 0 {
                    let death = RespawnController.deathRecovery(checkpointPosition: CheckpointController.respawnPosition(session: session, layout: worldLayout), maxHP: maxHP)
                    performDeathRecovery(death)
                }
            }
        }
    }'''
scene = replace_block(scene, "    private func updateEnemies(_ dt: TimeInterval) {", "    private func resetEnemyControllersFromSession", update_enemies)

reset_enemies = r'''    private func resetEnemyControllersFromSession() {
        for spec in worldLayout.enemies {
            let controller = TestEnemyController(spec: spec, snapshot: session.enemyStates[spec.id])
            enemyControllers[spec.id] = controller
            if let node = enemyNodes[spec.id] { node.position = controller.position; node.isHidden = !controller.isAlive }
            enemyHealthBars[spec.id]?.updateHealthBar(current: controller.hp, max: spec.maxHP)
        }
    }'''
scene = replace_block(scene, "    private func resetEnemyControllersFromSession() {", "    private func processAttackHits", reset_enemies)

process_hits = r'''    private func processAttackHits() {
        guard attackController.isHitboxActive else { return }
        let hitbox = CGRect(x: player.position.x + facing * 62 - 55, y: player.position.y - 42, width: 110, height: 84)
        for (id, controller) in enemyControllers where controller.isAlive {
            guard let node = enemyNodes[id], hitbox.intersects(node.calculateAccumulatedFrame()) else { continue }
            let markerKey = "attack-hit-\(id)-\(attackController.attackRemaining)"
            if player.userData?[markerKey] as? Bool == true { continue }
            if player.userData == nil { player.userData = NSMutableDictionary() }
            player.userData?[markerKey] = true
            if controller.receiveMeleeHit() {
                essenceController.gainFromAcceptedMeleeHit()
                session.enemyStates[id] = controller.snapshot()
                if let spec = worldLayout.enemies.first(where: { $0.id == id }) {
                    enemyHealthBars[id]?.updateHealthBar(current: controller.hp, max: spec.maxHP)
                }
                node.run(SKAction.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeAlpha(to: 1, duration: 0.08)]))
            }
        }
        if !attackController.isAttacking { player.userData = NSMutableDictionary() }
    }'''
scene = replace_block(scene, "    private func processAttackHits() {", "    private func updateTutorial", process_hits)

tutorial = r'''    private func updateTutorial() {
        tutorialController.update(playerPosition: player.position)
        guard let presentation = tutorialController.presentation else {
            tutorialLabel.text = ""; clearTutorialButtonHighlights(); return
        }
        tutorialLabel.text = presentation.text
        clearTutorialButtonHighlights()
        switch presentation.target {
        case .hud(let id):
            switch id {
            case "JUMP": pulseTutorial(jumpButton)
            case "DASH": pulseTutorial(dashButton)
            case "ATK": pulseTutorial(attackButton)
            case "HEAL": pulseTutorial(healButton)
            case "ACTION": pulseTutorial(actionButton)
            case "MOVE": pulseTutorial(rightButton)
            default: break
            }
        case .world(let id):
            worldNodes[id]?.run(SKAction.sequence([.fadeAlpha(to: 0.5, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)]), withKey: "tutorialPulse")
        case .none: break
        }
    }'''
scene = replace_block(scene, "    private func updateTutorial() {", "    private func pulseTutorial", tutorial)

pulse_tutorial = r'''    private func pulseTutorial(_ button: SKShapeNode) {
        button.strokeColor = .yellow
        button.lineWidth = 5
        if button.action(forKey: "tutorialPulse") == nil {
            button.run(SKAction.repeatForever(SKAction.sequence([.scale(to: 1.10, duration: 0.28), .scale(to: 1.0, duration: 0.28)])), withKey: "tutorialPulse")
        }
        tutorialArrow.removeAllActions()
        tutorialArrow.isHidden = false
        tutorialArrow.position = CGPoint(x: button.position.x, y: button.position.y + 72)
        tutorialArrow.run(SKAction.repeatForever(SKAction.sequence([.moveBy(x: 0, y: -8, duration: 0.28), .moveBy(x: 0, y: 8, duration: 0.28)])), withKey: "tutorialArrowPulse")
    }'''
scene = replace_block(scene, "    private func pulseTutorial(_ button: SKShapeNode) {", "    private func clearTutorialButtonHighlights", pulse_tutorial)

clear_highlights = r'''    private func clearTutorialButtonHighlights() {
        tutorialArrow.removeAllActions()
        tutorialArrow.isHidden = true
        for b in [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton, actionButton] {
            b.removeAction(forKey: "tutorialPulse")
            b.setScale(1)
            b.strokeColor = UIColor(white: 1, alpha: 0.16)
            b.lineWidth = 2
            if b.alpha < 0.4 { b.alpha = 1 }
        }
    }'''
scene = replace_block(scene, "    private func clearTutorialButtonHighlights() {", "    private func movePlayer", clear_highlights)

hud_status = r'''    private func updateHUDStatus() {
        let wallText = currentWallCling == nil ? "" : " • СТЕНА"
        statusLabel.text = "ЗДОРОВЬЕ \(currentHP)/\(maxHP) • СВЕТ \(essenceController.essence)/\(essenceController.maxEssence)\(wallText)"
        healButton.alpha = essenceController.essence >= essenceController.healCost && currentHP < maxHP ? 1 : 0.45
        dashButton.alpha = dashController.cooldownRemaining <= 0 ? 1 : 0.5
    }'''
scene = replace_block(scene, "    private func updateHUDStatus() {", "    private func refreshButtonVisuals", hud_status)

scene_path.write_text(scene, encoding="utf-8")

view = view_path.read_text(encoding="utf-8")
old_label = 'Text("v1.4 • PERFECTED TEST LOCATION")'
if old_label not in view:
    raise SystemExit("missing v1.4 visible label")
view = view.replace(old_label, 'Text("v1.5 • ПОНЯТНЫЕ МЕХАНИКИ • RU")')
view_path.write_text(view, encoding="utf-8")

plist = plist_path.read_text(encoding="utf-8")
old_version = '<key>CFBundleShortVersionString</key><string>1.4</string>'
if old_version not in plist:
    raise SystemExit("missing v1.4 plist version")
plist = plist.replace(old_version, '<key>CFBundleShortVersionString</key><string>1.5</string>')
plist_path.write_text(plist, encoding="utf-8")

print("Applied v1.5 feedback integration")
