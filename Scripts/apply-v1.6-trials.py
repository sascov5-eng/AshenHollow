#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
view_path = Path("Sources/GameView.swift")
plist_path = Path("Info.plist")
runtime_path = Path("Sources/V15RuntimeSupport.swift")
scene = scene_path.read_text(encoding="utf-8")
runtime = runtime_path.read_text(encoding="utf-8")


def need(text: str, old: str, new: str) -> str:
    if old not in text:
        raise SystemExit(f"v1.6 marker missing: {old[:120]!r}")
    return text.replace(old, new, 1)


def replace_block(text: str, start: str, end: str, replacement: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"v1.6 start marker missing: {start!r}")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"v1.6 end marker missing: {end!r}")
    return text[:a] + replacement.rstrip() + "\n\n" + text[b:]

# --- GameSceneV14: trial state and initializer ---
scene = need(
    scene,
    "final class GameSceneV14: SKScene {\n    private let tuning = PlayerMovementTuning.current",
    '''final class GameSceneV14: SKScene {
    // v1.6 timed trials
    private let trialDefinition: TrialDefinition
    var onTrialCompleted: ((TrialRunResult) -> Void)?
    private var trialElapsed: TimeInterval = 0
    private var trialDamageTaken = 0
    private var trialEnemiesDefeated = 0
    private var trialCompleted = false
    private var hitStopRemaining: TimeInterval = 0

    init(size: CGSize, trialDefinition: TrialDefinition = TrialCatalog.first) {
        self.trialDefinition = trialDefinition
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.trialDefinition = TrialCatalog.first
        super.init(coder: aDecoder)
    }

    private let tuning = PlayerMovementTuning.current'''
)

scene = need(
    scene,
    "        buildWorld()\n        buildPlayer()",
    "        buildWorld()\n        configureTrialWorld()\n        buildPlayer()"
)
scene = need(
    scene,
    "        initializeEnemySessionState()\n    }",
    "        initializeEnemySessionState()\n        beginTrialAttempt()\n    }"
)

# Semi-transparent HUD buttons.
scene = scene.replace(
    "button.fillColor = UIColor(white: 0.12, alpha: 0.62)",
    "button.fillColor = UIColor(white: 0.10, alpha: 0.54)"
)

# Focus cancels whenever the existing gameplay cancels focus.
scene = scene.replace("essenceController.cancelFocus()", "cancelHealFocusFX()")

# Hit stop + timer update.
scene = need(
    scene,
    "        recoveryLockRemaining = max(0, recoveryLockRemaining - dt)\n        damageController.update(dt: dt)",
    '''        if hitStopRemaining > 0 {
            hitStopRemaining = max(0, hitStopRemaining - dt)
            updateHUDStatus()
            return
        }
        if !trialCompleted && recoveryLockRemaining <= 0 { trialElapsed += dt }
        recoveryLockRemaining = max(0, recoveryLockRemaining - dt)
        damageController.update(dt: dt)'''
)
scene = need(
    scene,
    "        updateHUDStatus()\n    }\n\n    private func updateTimers",
    "        updateHUDStatus()\n        updateTrialCompletion()\n    }\n\n    private func updateTimers"
)

update_timers = '''    private func updateTimers(_ dt: TimeInterval) {
        if isGrounded { coyoteTimer = tuning.coyoteDuration; dashController.restoreAirDash() }
        else { coyoteTimer = max(0, coyoteTimer - dt) }
        jumpBufferTimer = max(0, jumpBufferTimer - dt)
        dashController.update(dt: dt)
        wallController.update(dt: dt)
        attackController.update(dt)
        essenceController.updateFocus(dt: dt)
        if essenceController.consumeCompletedHeal() {
            currentHP = min(maxHP, currentHP + 1)
            completeHealFocusFX()
        }
    }'''
scene = replace_block(scene, "    private func updateTimers(_ dt: TimeInterval) {", "    private func updateWallState", update_timers)

scene = need(
    scene,
    "    private func updateHorizontal(_ dt: CGFloat) {\n        if recoveryLockRemaining > 0 { velocity.dx = 0; return }",
    '''    private func updateHorizontal(_ dt: CGFloat) {
        if recoveryLockRemaining > 0 { velocity.dx = 0; return }
        if essenceController.isFocusing { velocity.dx = 0; moveInput = 0; return }'''
)
scene = scene.replace(
    "guard recoveryLockRemaining <= 0, jumpBufferTimer > 0 else { return }",
    "guard recoveryLockRemaining <= 0, !essenceController.isFocusing, jumpBufferTimer > 0 else { return }",
    1
)

start_heal = '''    private func startHeal() {
        guard recoveryLockRemaining <= 0, isGrounded,
              essenceController.beginFocus(currentHP: currentHP, maxHP: maxHP) else { return }
        velocity.dx = 0
        moveInput = 0
        targetMoveInput = 0
        beginHealFocusFX()
    }'''
scene = replace_block(scene, "    private func startHeal() {", "    private func startAction", start_heal)

# Reliable action interaction: nearest checkpoint/lever rather than a narrow facing probe.
action_block = '''    private func startAction() {
        guard recoveryLockRemaining <= 0 else { return }
        activateNearbyAction()
    }

    private func nearestActionCandidate() -> InteractionSpec? {
        worldLayout.interactions
            .filter { $0.kind == .lever || $0.kind == .shortcutLever }
            .map { interaction -> (InteractionSpec, CGFloat) in
                let center = CGPoint(x: interaction.rect.midX, y: interaction.rect.midY)
                return (interaction, hypot(center.x - player.position.x, center.y - player.position.y))
            }
            .filter { $0.1 <= 190 }
            .min(by: { $0.1 < $1.1 })?.0
    }

    private func activateNearbyAction() {
        if let cp = worldLayout.checkpoints
            .map({ ($0, hypot($0.position.x - player.position.x, $0.position.y - player.position.y)) })
            .filter({ $0.1 <= 145 })
            .min(by: { $0.1 < $1.1 })?.0 {
            let state = PlayerResourceState(hp: currentHP, maxHP: maxHP, light: essenceController.essence)
            if let result = CheckpointController.activate(id: cp.id, playerState: state, session: session, layout: worldLayout) {
                currentHP = result.player.hp
                worldNodes[cp.id]?.alpha = 1
                worldNodes[cp.id]?.run(SKAction.repeat(SKAction.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.12)]), count: 2))
                tutorialController.register(action: .checkpoint)
                return
            }
        }

        guard let interaction = nearestActionCandidate() else { return }
        if interactionController.activateLever(id: interaction.id) {
            tutorialController.register(action: interaction.kind == .lever ? .lever : .shortcut)
            setLeverVisual(id: interaction.id, active: true)
            if let linked = interaction.linkedID { openDoorVisual(id: linked) }
            applyInteractionVisualState()
            refreshCollisionRects()
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
scene = replace_block(scene, "    private func startAction() {", "    private func updateMovingPlatforms", action_block)

interaction_visuals = '''    private func applyInteractionVisualState() {
        for interaction in worldLayout.interactions {
            switch interaction.kind {
            case .lever, .shortcutLever:
                setLeverVisual(id: interaction.id, active: interactionController.isOpen(interaction.id))
            case .door, .shortcutDoor:
                if interactionController.isOpen(interaction.id) { openDoorVisual(id: interaction.id) }
            case .breakableWall:
                if interactionController.isSecretDestroyed(interaction.id), let node = worldNodes[interaction.id], !node.isHidden {
                    node.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.18), .hide()]))
                }
            case .hiddenPassage:
                break
            }
        }
    }

    private func setLeverVisual(id: String, active: Bool) {
        guard let handle = worldNodes[id]?.childNode(withName: "//leverHandle") else { return }
        let target: CGFloat = active ? 0.58 : -0.55
        if abs(handle.zRotation - target) > 0.02 {
            handle.run(.rotate(toAngle: target, duration: 0.16, shortestUnitArc: true), withKey: "leverState")
        }
    }

    private func openDoorVisual(id: String) {
        guard let root = worldNodes[id], let body = root.childNode(withName: "//doorBody") else { return }
        guard body.action(forKey: "doorOpen") == nil, !body.isHidden else { return }
        let interaction = worldLayout.interactions.first(where: { $0.id == id })
        let travel = (interaction?.rect.height ?? 220) + 50
        let action = SKAction.sequence([
            .group([.moveBy(x: 0, y: travel, duration: 0.34), .fadeAlpha(to: 0.15, duration: 0.34)]),
            .hide()
        ])
        action.timingMode = .easeInEaseOut
        body.run(action, withKey: "doorOpen")
    }'''
scene = replace_block(scene, "    private func applyInteractionVisualState() {", "    private func updateSafePosition", interaction_visuals)

# Count damage for rankings.
scene = scene.replace(
    "        case .spikeDamage:\n            tutorialController.register(action: .spikes)",
    "        case .spikeDamage:\n            trialDamageTaken += 1\n            tutorialController.register(action: .spikes)",
    1
)
scene = scene.replace(
    "                cancelHealFocusFX()\n                currentHP = max(0, currentHP - hit.hpLoss)",
    "                cancelHealFocusFX()\n                trialDamageTaken += hit.hpLoss\n                currentHP = max(0, currentHP - hit.hpLoss)",
    1
)

# Death restarts the timed attempt at the room start while preserving opened interaction state.
death_block = '''    private func performDeathRecovery(_ result: RecoveryResult) {
        currentHP = maxHP
        session.activeCheckpointID = nil
        session.preserveAcrossDeathResetEnemies(worldLayout.enemies)
        resetEnemyControllersFromSession()
        lifeController.respawn()
        trialElapsed = 0
        trialDamageTaken = 0
        trialEnemiesDefeated = 0
        trialCompleted = false
        cancelHealFocusFX()
        let restart = RecoveryResult(
            position: CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y),
            hp: maxHP,
            invulnerability: result.invulnerability,
            transitionDuration: result.transitionDuration,
            resetsEnemies: true
        )
        performRecovery(restart)
    }'''
scene = replace_block(scene, "    private func performDeathRecovery(_ result: RecoveryResult) {", "    private func flashRecovery", death_block)

# Melee: knock enemy away, short hit-stop, feedback, kill count.
hit_block = '''    private func processAttackHits() {
        guard attackController.isHitboxActive else { return }
        let hitbox = CGRect(x: player.position.x + facing * 62 - 55, y: player.position.y - 42, width: 110, height: 84)
        for (id, controller) in enemyControllers where controller.isAlive {
            guard !hitEnemiesThisAttack.contains(id) else { continue }
            guard let node = enemyNodes[id], hitbox.intersects(node.calculateAccumulatedFrame()) else { continue }
            hitEnemiesThisAttack.insert(id)
            let wasAlive = controller.isAlive
            if controller.receiveMeleeHit() {
                controller.applyMeleeKnockback(fromX: player.position.x, force: 210, stun: 0.13)
                essenceController.gainFromAcceptedMeleeHit()
                session.enemyStates[id] = controller.snapshot()
                if let spec = worldLayout.enemies.first(where: { $0.id == id }) {
                    enemyHealthBars[id]?.updateHealthBar(current: controller.hp, max: spec.maxHP)
                }
                if wasAlive && !controller.isAlive { trialEnemiesDefeated += 1 }
                showMeleeImpact(at: controller.position)
                hitStopRemaining = max(hitStopRemaining, 0.05)
                node.run(SKAction.sequence([.fadeAlpha(to: 0.18, duration: 0.035), .fadeAlpha(to: 1, duration: 0.09)]))
            }
        }
    }'''
scene = replace_block(scene, "    private func processAttackHits() {", "    private func updateTutorial", hit_block)

# Status adds timer.
hud_status = '''    private func updateHUDStatus() {
        let wallText = currentWallCling == nil ? "" : " • СТЕНА"
        statusLabel.text = "ЗДОРОВЬЕ \\(currentHP)/\\(maxHP) • СВЕТ \\(essenceController.essence)/\\(essenceController.maxEssence) • ВРЕМЯ \\(formatTrialTime())\\(wallText)"
        healButton.alpha = essenceController.essence >= essenceController.healCost && currentHP < maxHP ? 1 : 0.42
        dashButton.alpha = dashController.cooldownRemaining <= 0 ? 1 : 0.5
    }'''
# Correct escaped interpolation for Swift source.
hud_status = hud_status.replace('\\\\(', '\\(')
scene = replace_block(scene, "    private func updateHUDStatus() {", "    private func refreshButtonVisuals", hud_status)

helpers = r'''    private func configureTrialWorld() {
        let wallWidth: CGFloat = 70
        let left = CGRect(x: trialDefinition.minX - wallWidth, y: 0, width: wallWidth, height: worldLayout.worldBounds.height)
        let right = CGRect(x: trialDefinition.maxX, y: 0, width: wallWidth, height: worldLayout.worldBounds.height)
        staticPlatformRects.append(contentsOf: [left, right])
        for rect in [left, right] {
            let wall = PixelCaveArt.terrainNode(rect: rect)
            wall.zPosition = 6
            addChild(wall)
        }

        let finish = PixelCaveArt.exitNode()
        finish.name = "trialFinish"
        finish.position = CGPoint(x: trialDefinition.finishX, y: trialDefinition.finishY)
        finish.zPosition = 28
        addChild(finish)
        worldNodes["trial-finish"] = finish
    }

    private func beginTrialAttempt() {
        trialElapsed = 0
        trialDamageTaken = 0
        trialEnemiesDefeated = 0
        trialCompleted = false
        player.position = CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y)
        velocity = .zero
        safeTracker.reset(to: player.position)
        gameCamera.position = cameraController.reset(playerPosition: player.position, viewportSize: size, zoom: cameraZoom, worldBounds: worldLayout.worldBounds)
    }

    private func updateTrialCompletion() {
        guard !trialCompleted else { return }
        guard trialDefinition.finishRect.contains(player.position) else { return }
        trialCompleted = true
        targetMoveInput = 0
        moveInput = 0
        velocity = .zero
        let result = TrialRunResult(
            trialID: trialDefinition.id,
            elapsed: trialElapsed,
            damageTaken: trialDamageTaken,
            enemiesDefeated: trialEnemiesDefeated,
            rank: trialDefinition.rank(elapsed: trialElapsed, damageTaken: trialDamageTaken)
        )
        onTrialCompleted?(result)
    }

    private func formatTrialTime() -> String {
        String(format: "%.1f", trialElapsed)
    }

    private func showMeleeImpact(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 15)
        ring.position = point
        ring.strokeColor = .white
        ring.fillColor = UIColor.white.withAlphaComponent(0.14)
        ring.lineWidth = 4
        ring.glowWidth = 5
        ring.zPosition = 160
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.4, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))

        for i in 0..<6 {
            let shard = SKShapeNode(circleOfRadius: 2.5)
            shard.position = point
            shard.fillColor = .white
            shard.strokeColor = .clear
            shard.zPosition = 161
            addChild(shard)
            let angle = CGFloat(i) / 6 * .pi * 2
            let move = SKAction.moveBy(x: cos(angle) * 34, y: sin(angle) * 34, duration: 0.13)
            shard.run(.sequence([.group([move, .fadeOut(withDuration: 0.13)]), .removeFromParent()]))
        }
    }

    private func beginHealFocusFX() {
        player.childNode(withName: "healFocusFX")?.removeFromParent()
        let root = SKNode()
        root.name = "healFocusFX"
        root.zPosition = 120
        player.addChild(root)

        let ring = SKShapeNode(circleOfRadius: 42)
        ring.name = "healFocusRing"
        ring.strokeColor = UIColor(red: 0.65, green: 0.95, blue: 1, alpha: 0.95)
        ring.fillColor = UIColor(red: 0.25, green: 0.75, blue: 1, alpha: 0.08)
        ring.lineWidth = 4
        ring.glowWidth = 8
        root.addChild(ring)
        ring.run(.repeatForever(.sequence([.scale(to: 1.16, duration: 0.35), .scale(to: 0.92, duration: 0.35)])))

        for i in 0..<10 {
            let particle = SKShapeNode(circleOfRadius: 3)
            let angle = CGFloat(i) / 10 * .pi * 2
            particle.position = CGPoint(x: cos(angle) * 48, y: sin(angle) * 48)
            particle.fillColor = .white
            particle.strokeColor = .cyan
            particle.glowWidth = 3
            root.addChild(particle)
        }
        root.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 1.0)))
    }

    private func completeHealFocusFX() {
        let old = player.childNode(withName: "healFocusFX")
        old?.removeAllActions()
        old?.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))

        let flash = SKShapeNode(circleOfRadius: 32)
        flash.strokeColor = .white
        flash.fillColor = UIColor.cyan.withAlphaComponent(0.18)
        flash.lineWidth = 6
        flash.glowWidth = 12
        flash.zPosition = 130
        player.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 2.5, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
    }

    private func cancelHealFocusFX() {
        essenceController.cancelFocus()
        if let fx = player.childNode(withName: "healFocusFX") {
            fx.removeAllActions()
            fx.run(.sequence([.fadeOut(withDuration: 0.10), .removeFromParent()]))
        }
    }
'''
scene = need(scene, "    private func movePlayer(_ dt: CGFloat) {", helpers + "\n    private func movePlayer(_ dt: CGFloat) {")

# --- Pixel Cave interaction visuals: readable framed door + named moving parts ---
interaction_runtime = r'''    static func interactionNode(kind: InteractionKind, rect: CGRect) -> SKNode {
        let root = SKNode()
        switch kind {
        case .lever, .shortcutLever:
            if let sprite = sprite("Individual PNG files/Tileset/object_misc/objects_misc_13.png", size: CGSize(width: 70, height: 92), z: 2) { root.addChild(sprite) }
            let base = SKShapeNode(rectOf: CGSize(width: 34, height: 58), cornerRadius: 7)
            base.fillColor = UIColor(red: 0.10, green: 0.09, blue: 0.12, alpha: 0.95)
            base.strokeColor = UIColor(white: 0.75, alpha: 0.7)
            base.lineWidth = 2
            base.position = CGPoint(x: 0, y: -8)
            base.zPosition = 3
            root.addChild(base)
            let handle = SKShapeNode(rectOf: CGSize(width: 12, height: 58), cornerRadius: 5)
            handle.name = "leverHandle"
            handle.fillColor = .systemYellow
            handle.strokeColor = .white
            handle.lineWidth = 2
            handle.zRotation = -0.55
            handle.position = CGPoint(x: 8, y: 30)
            handle.zPosition = 6
            root.addChild(handle)
        case .door, .shortcutDoor:
            let doorWidth = Swift.max(CGFloat(94), rect.width + 38)
            let doorHeight = Swift.max(CGFloat(160), rect.height)
            let frame = SKShapeNode(rectOf: CGSize(width: doorWidth + 22, height: doorHeight + 20), cornerRadius: 10)
            frame.name = "doorFrame"
            frame.fillColor = UIColor(red: 0.045, green: 0.04, blue: 0.06, alpha: 0.96)
            frame.strokeColor = UIColor(red: 0.58, green: 0.62, blue: 0.72, alpha: 0.9)
            frame.lineWidth = 7
            frame.zPosition = 1
            root.addChild(frame)

            let body = SKNode()
            body.name = "doorBody"
            body.zPosition = 3
            let slab = SKShapeNode(rectOf: CGSize(width: doorWidth, height: doorHeight), cornerRadius: 5)
            slab.fillColor = UIColor(red: 0.09, green: 0.075, blue: 0.11, alpha: 1)
            slab.strokeColor = UIColor(red: 0.42, green: 0.46, blue: 0.56, alpha: 0.9)
            slab.lineWidth = 3
            body.addChild(slab)
            if let texture = texture("Individual PNG files/Tileset/object_misc/objects_misc_0.png") {
                let rows = Swift.max(3, Int(ceil(doorHeight / 48)))
                for i in 0..<rows {
                    let tile = SKSpriteNode(texture: texture)
                    tile.size = CGSize(width: doorWidth - 10, height: 48)
                    tile.position = CGPoint(x: 0, y: -doorHeight * 0.5 + 24 + CGFloat(i) * 48)
                    tile.alpha = 0.88
                    tile.zPosition = 2
                    body.addChild(tile)
                }
            }
            root.addChild(body)
        case .breakableWall:
            let body = terrainNode(rect: CGRect(x: -rect.width * 0.5, y: -rect.height * 0.5, width: rect.width, height: rect.height))
            root.addChild(body)
            let crack = SKShapeNode(path: {
                let p = CGMutablePath(); p.move(to: CGPoint(x: -8, y: 65)); p.addLine(to: CGPoint(x: 7, y: 25)); p.addLine(to: CGPoint(x: -4, y: 2)); p.addLine(to: CGPoint(x: 12, y: -32)); p.addLine(to: CGPoint(x: -6, y: -68)); return p
            }())
            crack.strokeColor = .white; crack.lineWidth = 3; crack.zPosition = 8; root.addChild(crack)
        case .hiddenPassage:
            let outline = SKShapeNode(rectOf: rect.size, cornerRadius: 8)
            outline.strokeColor = UIColor.cyan.withAlphaComponent(0.7)
            outline.fillColor = UIColor.cyan.withAlphaComponent(0.05)
            outline.lineWidth = 2
            root.addChild(outline)
        }
        return root
    }'''
runtime = replace_block(runtime, "    static func interactionNode(kind: InteractionKind, rect: CGRect) -> SKNode {", "    static func enemyNode", interaction_runtime)
runtime_path.write_text(runtime, encoding="utf-8")

# --- Full SwiftUI demo shell ---
view = r'''import SwiftUI
import SpriteKit

private enum DemoScreen {
    case mainMenu, trials, playing, paused, results, settings, about
}

private final class DemoCoordinator: ObservableObject {
    @Published var screen: DemoScreen = .mainMenu
    @Published var scene: GameSceneV14
    @Published var selectedTrial: TrialDefinition = TrialCatalog.first
    @Published var result: TrialRunResult?

    init() {
        DemoSettingsStore.registerDefaults()
        let initial = GameSceneV14(size: CGSize(width: 844, height: 390), trialDefinition: TrialCatalog.first)
        initial.scaleMode = .resizeFill
        scene = initial
    }

    func start(_ trial: TrialDefinition) {
        selectedTrial = trial
        result = nil
        let next = GameSceneV14(size: CGSize(width: 844, height: 390), trialDefinition: trial)
        next.scaleMode = .resizeFill
        next.onTrialCompleted = { [weak self] result in
            DispatchQueue.main.async {
                TrialProgressStore.save(result)
                self?.result = result
                self?.screen = .results
            }
        }
        scene = next
        screen = .playing
    }

    func pause() {
        scene.isPaused = true
        screen = .paused
    }

    func resume() {
        scene.isPaused = false
        screen = .playing
    }

    func restart() {
        start(selectedTrial)
    }

    func showTrials() {
        scene.isPaused = false
        screen = .trials
    }

    func showMenu() {
        scene.isPaused = false
        screen = .mainMenu
    }
}

struct GameView: View {
    @StateObject private var coordinator = DemoCoordinator()
    @AppStorage(DemoSettingsStore.musicVolumeKey) private var musicVolume = 0.75
    @AppStorage(DemoSettingsStore.effectsVolumeKey) private var effectsVolume = 0.85
    @AppStorage(DemoSettingsStore.vibrationEnabledKey) private var vibrationEnabled = true

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.018, blue: 0.028).ignoresSafeArea()
            switch coordinator.screen {
            case .mainMenu: mainMenu
            case .trials: trialSelection
            case .playing: gameplay
            case .paused: gameplay.overlay(pauseOverlay)
            case .results: resultsView
            case .settings: settingsView
            case .about: aboutView
            }

            VStack {
                Text("v1.6 • ИСПЫТАНИЯ • БОЙ + UI")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.black.opacity(0.78))
                Spacer()
            }
            .padding(.top, 5)
            .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
    }

    private var mainMenu: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("ASHEN HOLLOW")
                .font(.system(size: 42, weight: .black, design: .serif))
                .foregroundColor(.white)
            Text("ИСПЫТАНИЯ")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.9))
            menuButton("ИГРАТЬ") { coordinator.showTrials() }
            menuButton("НАСТРОЙКИ") { coordinator.screen = .settings }
            menuButton("ОБ ИГРЕ") { coordinator.screen = .about }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var trialSelection: some View {
        VStack(spacing: 10) {
            Text("КОМНАТЫ ИСПЫТАНИЙ").font(.system(size: 25, weight: .black))
            Text("Проходи быстрее • получай ранги A / B / C / D")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.65))
            HStack(spacing: 10) {
                ForEach(TrialCatalog.all) { trial in
                    Button {
                        coordinator.start(trial)
                    } label: {
                        VStack(spacing: 5) {
                            Text(trial.title).font(.system(size: 12, weight: .heavy)).multilineTextAlignment(.center)
                            Text(trial.subtitle).font(.system(size: 9)).foregroundColor(.white.opacity(0.65)).multilineTextAlignment(.center)
                            if let best = TrialProgressStore.bestTime(for: trial.id) {
                                Text(String(format: "ЛУЧШЕЕ %.1fс", best)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                            } else {
                                Text("НЕТ РЕЗУЛЬТАТА").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(10)
                        .frame(width: 125, height: 112)
                        .background(Color.white.opacity(0.075))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.22), lineWidth: 1.5))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("В МЕНЮ") { coordinator.showMenu() }
                .font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.75)).padding(.top, 4)
        }
        .padding(.top, 34)
    }

    private var gameplay: some View {
        ZStack(alignment: .topLeading) {
            SpriteView(scene: coordinator.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .background(Color.black)
            Button {
                coordinator.pause()
            } label: {
                Text("Ⅱ").font(.system(size: 18, weight: .black))
                    .frame(width: 46, height: 40)
                    .background(Color.black.opacity(0.48)).clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.leading, 12).padding(.top, 36)
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("ПАУЗА").font(.system(size: 28, weight: .black))
                menuButton("ПРОДОЛЖИТЬ") { coordinator.resume() }
                menuButton("ПЕРЕЗАПУСТИТЬ") { coordinator.restart() }
                menuButton("В МЕНЮ") { coordinator.showMenu() }
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 10) {
            Text("РЕЗУЛЬТАТ").font(.system(size: 24, weight: .black))
            if let result = coordinator.result {
                Text("РАНГ \\(result.rank.rawValue)")
                    .font(.system(size: 54, weight: .black, design: .rounded)).foregroundColor(.cyan)
                Text(String(format: "ВРЕМЯ %.1fс", result.elapsed)).font(.system(size: 16, weight: .bold, design: .monospaced))
                Text("УРОН \\(result.damageTaken)  •  ВРАГОВ \\(result.enemiesDefeated)")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.72))
            }
            HStack(spacing: 12) {
                menuButton("ЕЩЁ РАЗ") { coordinator.restart() }
                menuButton("ИСПЫТАНИЯ") { coordinator.showTrials() }
            }
        }
    }

    private var settingsView: some View {
        VStack(spacing: 14) {
            Text("НАСТРОЙКИ").font(.system(size: 26, weight: .black))
            settingSlider("МУЗЫКА", value: $musicVolume)
            settingSlider("ЭФФЕКТЫ", value: $effectsVolume)
            Toggle("ВИБРАЦИЯ", isOn: $vibrationEnabled)
                .font(.system(size: 13, weight: .bold)).frame(width: 330)
            menuButton("В МЕНЮ") { coordinator.showMenu() }
        }
    }

    private var aboutView: some View {
        VStack(spacing: 12) {
            Text("ОБ ИГРЕ").font(.system(size: 26, weight: .black))
            Text("Ashen Hollow — компактная демо-версия с комнатами испытаний, платформингом и боем.")
                .multilineTextAlignment(.center).frame(width: 500)
            Text("КОНФИДЕНЦИАЛЬНОСТЬ")
                .font(.system(size: 13, weight: .heavy)).foregroundColor(.cyan)
            Text("Демо не использует рекламу, аналитику, аккаунты или передачу персональных данных. Настройки и лучшие результаты сохраняются только на этом устройстве.")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.72)).multilineTextAlignment(.center).frame(width: 560)
            menuButton("В МЕНЮ") { coordinator.showMenu() }
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .heavy))
                .frame(minWidth: 165).padding(.vertical, 9).padding(.horizontal, 14)
                .background(Color.white.opacity(0.095))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.28), lineWidth: 1.5))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func settingSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 12, weight: .bold)).frame(width: 90, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
        .frame(width: 360)
    }
}
'''
# Raw string above intentionally contains doubled interpolation escapes; normalize for Swift.
view = view.replace('\\\\(', '\\(')
view_path.write_text(view, encoding="utf-8")

# Release metadata after v1.5 integration.
plist = plist_path.read_text(encoding="utf-8")
plist = need(plist, '<key>CFBundleShortVersionString</key><string>1.5</string>', '<key>CFBundleShortVersionString</key><string>1.6</string>')
plist_path.write_text(plist, encoding="utf-8")

scene_path.write_text(scene, encoding="utf-8")
print("Applied v1.6 trials, combat feedback, interaction and demo shell integration")
