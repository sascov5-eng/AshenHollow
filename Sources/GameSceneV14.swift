import SpriteKit
import UIKit

final class GameSceneV14: SKScene {
    private let tuning = PlayerMovementTuning.current
    private let worldLayout = TestLocationLayout.v14
    private var cameraController = CinematicCameraController()
    private let session = TestSessionState()
    private lazy var tutorialController = DeveloperTutorialController(layout: worldLayout, session: session)
    private lazy var interactionController = TestInteractionController(layout: worldLayout, session: session)
    private let safeTracker = SafePositionTracker()

    private let player = SKShapeNode(rectOf: CGSize(width: 42, height: 64), cornerRadius: 10)
    private let playerVisual = SKNode()
    private var playerSprite: SKSpriteNode?
    private var animationLibrary = PlayerAnimationLibrary()
    private var currentAnimation: PlayerAnimationKey?
    private var activeAttackAnimation: PlayerAnimationKey = .attack1

    private let gameCamera = SKCameraNode()
    private let hud = SKNode()
    private let tutorialLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let recoveryOverlay = SKShapeNode()

    private var staticPlatformRects: [CGRect] = []
    private var platformRects: [CGRect] = []
    private var worldNodes: [String: SKNode] = [:]
    private var movingControllers: [String: MovingPlatformController] = [:]
    private var movingNodes: [String: SKShapeNode] = [:]
    private var enemyControllers: [String: TestEnemyController] = [:]
    private var enemyNodes: [String: SKShapeNode] = [:]

    private var velocity = CGVector.zero
    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1
    private var isGrounded = false
    private var jumpHeld = false
    private var coyoteTimer: TimeInterval = 0
    private var jumpBufferTimer: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var recoveryLockRemaining: TimeInterval = 0
    private var lastAttackSequenceProcessed = 0

    private var dashController = DashController()
    private var wallController = WallTraversalController()
    private var attackController = AttackController()
    private var essenceController = EssenceFocusController()
    private var damageController = PlayerDamageController()
    private var lifeController = PlayerLifeStateController()
    private var currentHP = 5
    private let maxHP = 5
    private var currentWallCling: WallSide?

    // Device-approved v1.3 view scale. Camera behavior itself remains in CinematicCameraController.
    private let cameraZoom: CGFloat = 1.75

    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let jumpButton = SKShapeNode(circleOfRadius: 51)
    private let attackButton = SKShapeNode(circleOfRadius: 44)
    private let dashButton = SKShapeNode(circleOfRadius: 44)
    private let healButton = SKShapeNode(circleOfRadius: 40)

    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let jumpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let attackLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let dashLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let healLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var leftTouches = Set<ObjectIdentifier>()
    private var rightTouches = Set<ObjectIdentifier>()
    private var jumpTouches = Set<ObjectIdentifier>()

    private var colliderSize: CGSize {
        CGSize(width: CGFloat(tuning.colliderWidth), height: CGFloat(tuning.colliderHeight))
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.018, green: 0.023, blue: 0.035, alpha: 1)
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        buildWorld()
        buildPlayer()
        buildEnemies()
        buildCamera()
        buildHUD()
        layoutHUD()
        refreshCollisionRects()

        isGrounded = isStandingOnSurface()
        coyoteTimer = isGrounded ? tuning.coyoteDuration : 0
        safeTracker.reset(to: player.position)
        initializeEnemySessionState()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
        if recoveryOverlay.parent != nil {
            recoveryOverlay.path = CGPath(rect: CGRect(x: -size.width, y: -size.height, width: size.width * 2, height: size.height * 2), transform: nil)
        }
    }

    private func buildWorld() {
        staticPlatformRects = worldLayout.collisionRects

        let backdrop = SKShapeNode(rectOf: worldLayout.worldBounds.size)
        backdrop.fillColor = UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldLayout.worldBounds.midX, y: worldLayout.worldBounds.midY)
        backdrop.zPosition = -120
        addChild(backdrop)

        // Broad cave silhouettes so the blockout reads as one connected place.
        for index in 0..<22 {
            let w: CGFloat = 260 + CGFloat(index % 4) * 80
            let h: CGFloat = 240 + CGFloat(index % 5) * 90
            let node = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 40)
            node.fillColor = UIColor(red: 0.045, green: 0.055, blue: 0.075, alpha: 0.70)
            node.strokeColor = .clear
            node.position = CGPoint(x: 260 + CGFloat(index) * 410, y: 180 + h * 0.5 + CGFloat(index % 3) * 170)
            node.zPosition = -70
            addChild(node)
        }

        for rect in staticPlatformRects {
            addBlock(rect, fill: UIColor(red: 0.14, green: 0.155, blue: 0.19, alpha: 1), stroke: UIColor(white: 0.46, alpha: 0.28), z: 1)
        }

        for hazard in worldLayout.hazards {
            switch hazard.kind {
            case .spikes:
                let node = addBlock(hazard.rect, fill: UIColor(red: 0.62, green: 0.17, blue: 0.15, alpha: 0.92), stroke: UIColor(red: 1, green: 0.45, blue: 0.3, alpha: 0.8), z: 12)
                worldNodes[hazard.id] = node
                addWorldCaption("SPIKES", at: CGPoint(x: hazard.rect.midX, y: hazard.rect.maxY + 38), color: .systemRed)
            case .deathZone:
                let node = addBlock(hazard.rect, fill: UIColor(red: 0.20, green: 0.02, blue: 0.05, alpha: 0.28), stroke: UIColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 0.5), z: -5)
                worldNodes[hazard.id] = node
                addWorldCaption("PIT / DEATH ZONE", at: CGPoint(x: hazard.rect.midX, y: hazard.rect.maxY - 35), color: .systemRed)
            }
        }

        for checkpoint in worldLayout.checkpoints {
            let node = SKShapeNode(rectOf: CGSize(width: 54, height: 92), cornerRadius: 18)
            node.fillColor = UIColor(red: 0.15, green: 0.55, blue: 0.66, alpha: 0.65)
            node.strokeColor = UIColor(red: 0.45, green: 0.95, blue: 1, alpha: 0.95)
            node.lineWidth = 3
            node.position = CGPoint(x: checkpoint.position.x, y: 136)
            node.zPosition = 20
            addChild(node)
            worldNodes[checkpoint.id] = node
            addWorldCaption("CHECKPOINT", at: CGPoint(x: checkpoint.position.x, y: 205), color: .cyan)
        }

        for spec in worldLayout.movingPlatforms {
            let controller = MovingPlatformController(spec: spec)
            movingControllers[spec.id] = controller
            let node = SKShapeNode(rectOf: spec.size, cornerRadius: 6)
            node.fillColor = UIColor(red: 0.17, green: 0.55, blue: 0.34, alpha: 1)
            node.strokeColor = UIColor(red: 0.5, green: 1, blue: 0.7, alpha: 0.9)
            node.lineWidth = 3
            node.position = spec.start
            node.zPosition = 10
            addChild(node)
            movingNodes[spec.id] = node
            worldNodes[spec.id] = node
        }

        for interaction in worldLayout.interactions {
            let node = SKShapeNode(rectOf: interaction.rect.size, cornerRadius: 5)
            switch interaction.kind {
            case .lever, .shortcutLever:
                node.fillColor = UIColor(red: 0.85, green: 0.65, blue: 0.18, alpha: 0.9)
                node.strokeColor = .yellow
            case .door, .shortcutDoor:
                node.fillColor = UIColor(red: 0.34, green: 0.25, blue: 0.48, alpha: 1)
                node.strokeColor = UIColor(red: 0.72, green: 0.55, blue: 1, alpha: 0.9)
            case .breakableWall:
                node.fillColor = UIColor(red: 0.45, green: 0.24, blue: 0.16, alpha: 1)
                node.strokeColor = .orange
            case .hiddenPassage:
                node.fillColor = UIColor(red: 0.15, green: 0.65, blue: 0.75, alpha: 0.16)
                node.strokeColor = UIColor.cyan.withAlphaComponent(0.6)
            }
            node.lineWidth = 3
            node.position = CGPoint(x: interaction.rect.midX, y: interaction.rect.midY)
            node.zPosition = 18
            addChild(node)
            worldNodes[interaction.id] = node
        }

        let exit = SKShapeNode(rectOf: worldLayout.exitMarker.size, cornerRadius: 18)
        exit.fillColor = UIColor(red: 0.20, green: 0.62, blue: 0.72, alpha: 0.32)
        exit.strokeColor = .cyan
        exit.lineWidth = 4
        exit.position = CGPoint(x: worldLayout.exitMarker.midX, y: worldLayout.exitMarker.midY)
        exit.zPosition = 15
        addChild(exit)
        worldNodes["exit"] = exit
        addWorldCaption("TEST AREA COMPLETE", at: CGPoint(x: worldLayout.exitMarker.midX, y: worldLayout.exitMarker.maxY + 45), color: .cyan)
    }

    @discardableResult
    private func addBlock(_ rect: CGRect, fill: UIColor, stroke: UIColor, z: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rectOf: rect.size, cornerRadius: min(9, min(rect.width, rect.height) * 0.12))
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = stroke == .clear ? 0 : 2
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.zPosition = z
        addChild(node)
        return node
    }

    private func addWorldCaption(_ text: String, at position: CGPoint, color: UIColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 17
        label.fontColor = color
        label.position = position
        label.zPosition = 60
        addChild(label)
    }

    private func buildPlayer() {
        player.removeFromParent()
        player.removeAllChildren()
        playerVisual.removeAllChildren()
        playerSprite = nil
        currentAnimation = nil

        player.fillColor = .clear
        player.strokeColor = .clear
        player.zPosition = 50
        player.position = worldLayout.spawnPoint

        animationLibrary = PlayerAnimationLibrary()
        if let first = animationLibrary.frames(for: .idle).first {
            let sprite = SKSpriteNode(texture: first)
            sprite.size = CGSize(width: 480, height: 480)
            sprite.position = CGPoint(x: 0, y: -8)
            sprite.zPosition = 10
            playerVisual.addChild(sprite)
            playerSprite = sprite
            setAnimation(.idle, force: true)
        }
        if playerSprite == nil {
            player.fillColor = .red
            player.strokeColor = .white
            player.lineWidth = 2
        }
        player.addChild(playerVisual)
        addChild(player)
        velocity = .zero
    }

    private func buildEnemies() {
        for spec in worldLayout.enemies {
            let controller = TestEnemyController(spec: spec)
            enemyControllers[spec.id] = controller
            let node = SKShapeNode(rectOf: CGSize(width: spec.kind == .flying ? 52 : 46, height: spec.kind == .flying ? 38 : 58), cornerRadius: 10)
            switch spec.kind {
            case .groundPatrol: node.fillColor = .systemOrange
            case .flying: node.fillColor = .systemTeal
            case .aggressive: node.fillColor = .systemPink
            }
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = spec.spawn
            node.zPosition = 42
            addChild(node)
            enemyNodes[spec.id] = node
        }
    }

    private func initializeEnemySessionState() {
        for spec in worldLayout.enemies {
            if session.enemyStates[spec.id] == nil {
                session.enemyStates[spec.id] = EnemyRuntimeSnapshot(hp: spec.maxHP, isAlive: true, position: spec.spawn)
            }
        }
    }

    private func buildCamera() {
        gameCamera.removeFromParent()
        addChild(gameCamera)
        camera = gameCamera
        gameCamera.setScale(cameraZoom)
        gameCamera.position = cameraController.reset(playerPosition: player.position, viewportSize: size, zoom: cameraZoom, worldBounds: worldLayout.worldBounds)
    }

    private func buildHUD() {
        hud.removeFromParent()
        hud.removeAllChildren()
        gameCamera.addChild(hud)
        hud.zPosition = 1000

        [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton].forEach(configureButton)
        configureLabel(leftArrow, text: "‹", size: 50)
        configureLabel(rightArrow, text: "›", size: 50)
        configureLabel(jumpLabel, text: "JUMP", size: 14)
        configureLabel(attackLabel, text: "ATK", size: 15)
        configureLabel(dashLabel, text: "DASH", size: 13)
        configureLabel(healLabel, text: "HEAL", size: 12)
        configureLabel(statusLabel, text: "", size: 11)
        configureLabel(tutorialLabel, text: "", size: 18)
        tutorialLabel.fontColor = .yellow

        leftButton.addChild(leftArrow); rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel); attackButton.addChild(attackLabel)
        dashButton.addChild(dashLabel); healButton.addChild(healLabel)
        [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton, statusLabel, tutorialLabel].forEach { hud.addChild($0) }

        recoveryOverlay.fillColor = .black
        recoveryOverlay.strokeColor = .clear
        recoveryOverlay.alpha = 0
        recoveryOverlay.zPosition = 2000
        recoveryOverlay.path = CGPath(rect: CGRect(x: -size.width, y: -size.height, width: size.width * 2, height: size.height * 2), transform: nil)
        hud.addChild(recoveryOverlay)
        updateHUDStatus()
    }

    private func configureButton(_ button: SKShapeNode) {
        button.fillColor = UIColor(white: 0.12, alpha: 0.62)
        button.strokeColor = UIColor(white: 1, alpha: 0.16)
        button.lineWidth = 2
    }

    private func configureLabel(_ label: SKLabelNode, text: String, size: CGFloat) {
        label.text = text
        label.fontSize = size
        label.fontColor = UIColor(white: 0.94, alpha: 0.92)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }

    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let bottom = max(72, size.height * 0.14)
        leftButton.position = CGPoint(x: -halfW + 82, y: -halfH + bottom)
        rightButton.position = CGPoint(x: -halfW + 182, y: -halfH + bottom)
        jumpButton.position = CGPoint(x: halfW - 88, y: -halfH + bottom + 4)
        attackButton.position = CGPoint(x: halfW - 190, y: -halfH + bottom + 28)
        dashButton.position = CGPoint(x: halfW - 88, y: -halfH + bottom + 112)
        healButton.position = CGPoint(x: halfW - 190, y: -halfH + bottom + 120)
        statusLabel.position = CGPoint(x: halfW - 150, y: halfH - 58)
        tutorialLabel.position = CGPoint(x: 0, y: halfH - 105)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard recoveryLockRemaining <= 0 else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)
            if isInside(point, button: leftButton, radius: 60) {
                leftTouches.insert(id); animateButton(leftButton, pressed: true); tutorialController.register(action: .move)
            } else if isInside(point, button: rightButton, radius: 60) {
                rightTouches.insert(id); animateButton(rightButton, pressed: true); tutorialController.register(action: .move)
            } else if isInside(point, button: attackButton, radius: 48) {
                startAttack(); pulse(attackButton); tutorialController.register(action: .attack)
            } else if isInside(point, button: dashButton, radius: 48) {
                startDash(); pulse(dashButton); tutorialController.register(action: .dash)
            } else if isInside(point, button: healButton, radius: 44) {
                startHeal(); pulse(healButton); tutorialController.register(action: .heal)
            } else if isInside(point, button: jumpButton, radius: 55) {
                jumpTouches.insert(id); jumpHeld = true; jumpBufferTimer = tuning.jumpBufferDuration
                tryConsumeJump(); animateButton(jumpButton, pressed: true); tutorialController.register(action: .jump)
            }
        }
        updateInputTarget()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard recoveryLockRemaining <= 0 else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)
            leftTouches.remove(id); rightTouches.remove(id)
            if isInside(point, button: leftButton, radius: 60) { leftTouches.insert(id) }
            else if isInside(point, button: rightButton, radius: 60) { rightTouches.insert(id) }
        }
        updateInputTarget(); refreshButtonVisuals()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { releaseTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { releaseTouches(touches) }

    private func releaseTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            leftTouches.remove(id); rightTouches.remove(id)
            if jumpTouches.remove(id) != nil && jumpTouches.isEmpty {
                jumpHeld = false
                if velocity.dy > CGFloat(tuning.jumpReleaseVelocity) { velocity.dy = CGFloat(tuning.jumpReleaseVelocity) }
            }
        }
        updateInputTarget(); refreshButtonVisuals()
    }

    private func isInside(_ point: CGPoint, button: SKShapeNode, radius: CGFloat) -> Bool {
        hypot(point.x - button.position.x, point.y - button.position.y) <= radius
    }

    private func updateInputTarget() {
        targetMoveInput = recoveryLockRemaining > 0 ? 0 : (leftTouches.isEmpty ? 0 : -1) + (rightTouches.isEmpty ? 0 : 1)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        recoveryLockRemaining = max(0, recoveryLockRemaining - dt)
        damageController.update(dt: dt)
        lifeController.update(dt: dt)
        updateMovingPlatforms(dt)
        refreshCollisionRects()
        updateTimers(dt)
        updateWallState()
        updateHorizontal(CGFloat(dt))
        tryConsumeJump()
        updateVertical(CGFloat(dt))
        movePlayer(CGFloat(dt))
        updateSafePosition()
        updateHazards()
        updateCheckpoints()
        updateInteractions()
        updateEnemies(dt)
        processAttackHits()
        updateTutorial()
        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
        updateHUDStatus()
    }

    private func updateTimers(_ dt: TimeInterval) {
        if isGrounded { coyoteTimer = tuning.coyoteDuration; dashController.restoreAirDash() }
        else { coyoteTimer = max(0, coyoteTimer - dt) }
        jumpBufferTimer = max(0, jumpBufferTimer - dt)
        dashController.update(dt: dt); wallController.update(dt: dt); attackController.update(dt); essenceController.updateFocus(dt: dt)
        if essenceController.consumeCompletedHeal() { currentHP = min(maxHP, currentHP + 1) }
    }

    private func updateWallState() {
        currentWallCling = wallController.clingSide(unlocked: true, isGrounded: isGrounded, heldDirectionX: Double(targetMoveInput), contactSide: wallContactSide())
    }

    private func updateHorizontal(_ dt: CGFloat) {
        if recoveryLockRemaining > 0 { velocity.dx = 0; return }
        if dashController.isDashing { velocity.dx = CGFloat(dashController.direction * tuning.dashSpeed); return }
        let inputResponse: CGFloat = 12
        moveInput += (targetMoveInput - moveInput) * min(1, inputResponse * dt)
        let targetVX = moveInput * CGFloat(tuning.runSpeed)
        let accelerating = abs(targetMoveInput) > 0.01
        let acceleration = accelerating ? CGFloat(isGrounded ? tuning.groundAcceleration : tuning.airAcceleration) : CGFloat(isGrounded ? tuning.groundDeceleration : tuning.airAcceleration * 0.5)
        velocity.dx = moveToward(velocity.dx, targetVX, maxDelta: acceleration * dt)
        if !accelerating && abs(velocity.dx) < 2 { velocity.dx = 0 }
        if abs(targetMoveInput) > 0.01 { facing = targetMoveInput > 0 ? 1 : -1 }
    }

    private func updateVertical(_ dt: CGFloat) {
        if recoveryLockRemaining > 0 { velocity.dy = 0; return }
        if dashController.isDashing { velocity.dy = 0; return }
        velocity.dy = max(-CGFloat(tuning.maxFallSpeed), velocity.dy - CGFloat(tuning.gravity) * dt)
        if currentWallCling != nil && velocity.dy < CGFloat(tuning.wallSlideSpeed) { velocity.dy = CGFloat(tuning.wallSlideSpeed) }
        if !jumpHeld && velocity.dy > CGFloat(tuning.jumpReleaseVelocity) { velocity.dy = CGFloat(tuning.jumpReleaseVelocity) }
    }

    private func tryConsumeJump() {
        guard recoveryLockRemaining <= 0, jumpBufferTimer > 0 else { return }
        if let side = currentWallCling {
            let impulse = wallController.wallJump(from: side)
            velocity.dx = CGFloat(impulse.velocityX); velocity.dy = CGFloat(impulse.velocityY)
            facing = velocity.dx >= 0 ? 1 : -1; isGrounded = false; currentWallCling = nil
            jumpBufferTimer = 0; coyoteTimer = 0; dashController.restoreAirDash(); setAnimation(.jump, force: true)
            tutorialController.register(action: .wallJump)
            return
        }
        guard isGrounded || coyoteTimer > 0 || isStandingOnSurface() else { return }
        velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false; coyoteTimer = 0; jumpBufferTimer = 0; setAnimation(.jump, force: true)
    }

    private func startDash() {
        guard recoveryLockRemaining <= 0,
              let direction = dashController.tryStart(unlocked: true, isGrounded: isGrounded, inputX: Double(targetMoveInput), facing: Double(facing)) else { return }
        essenceController.cancelFocus(); facing = direction >= 0 ? 1 : -1
        velocity.dx = CGFloat(direction * tuning.dashSpeed); velocity.dy = 0; setAnimation(.dash, force: true)
    }

    private func startAttack() {
        guard recoveryLockRemaining <= 0 else { return }
        essenceController.cancelFocus()
        guard attackController.tryStart(direction: .horizontal) else { return }
        activeAttackAnimation = .attack1
        setAnimation(.attack1, force: true)
        activateNearbyLeverOrSecret()
    }

    private func startHeal() {
        guard recoveryLockRemaining <= 0, essenceController.beginFocus(currentHP: currentHP, maxHP: maxHP) else { return }
        velocity.dx = 0
        let glow = SKAction.sequence([SKAction.fadeAlpha(to: 0.45, duration: 0.15), SKAction.fadeAlpha(to: 1, duration: 0.15)])
        playerVisual.run(SKAction.repeat(glow, count: 3), withKey: "heal")
    }

    private func activateNearbyLeverOrSecret() {
        let probe = CGRect(x: player.position.x + facing * 50 - 45, y: player.position.y - 55, width: 90, height: 110)
        for interaction in worldLayout.interactions where interaction.rect.intersects(probe) {
            if interaction.kind == .lever || interaction.kind == .shortcutLever {
                if interactionController.activateLever(id: interaction.id) { tutorialController.register(action: interaction.kind == .lever ? .lever : .shortcut) }
            } else if interaction.kind == .breakableWall {
                if interactionController.attackSecretWall(id: interaction.id) { tutorialController.register(action: .secretWall) }
            }
        }
        applyInteractionVisualState()
        refreshCollisionRects()
    }

    private func updateMovingPlatforms(_ dt: TimeInterval) {
        let playerFrameBefore = playerColliderFrame()
        for (id, controller) in movingControllers {
            let oldFrame = controller.frame
            let delta = controller.update(dt: dt)
            movingNodes[id]?.position = controller.state.position
            let riding = isGrounded && abs(playerFrameBefore.minY - oldFrame.maxY) < 5 && playerFrameBefore.maxX > oldFrame.minX && playerFrameBefore.minX < oldFrame.maxX
            if riding {
                player.position.x += delta.dx
                player.position.y += delta.dy
                tutorialController.register(action: controller.spec.axis == .horizontal ? .movingPlatformHorizontal : .movingPlatformVertical)
            }
        }
    }

    private func refreshCollisionRects() {
        platformRects = staticPlatformRects
        platformRects.append(contentsOf: movingControllers.values.map(\.frame))
        for interaction in worldLayout.interactions {
            switch interaction.kind {
            case .door, .shortcutDoor:
                if !interactionController.isOpen(interaction.id) { platformRects.append(interaction.rect) }
            case .breakableWall:
                if !interactionController.isSecretDestroyed(interaction.id) { platformRects.append(interaction.rect) }
            default: break
            }
        }
    }

    private func applyInteractionVisualState() {
        for interaction in worldLayout.interactions {
            guard let node = worldNodes[interaction.id] else { continue }
            if (interaction.kind == .door || interaction.kind == .shortcutDoor) && interactionController.isOpen(interaction.id) {
                node.run(SKAction.fadeAlpha(to: 0.12, duration: 0.22))
            }
            if interaction.kind == .breakableWall && interactionController.isSecretDestroyed(interaction.id) {
                node.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.18), .hide()]))
            }
        }
    }

    private func updateSafePosition() {
        let frame = playerColliderFrame()
        let touchingHazard = worldLayout.hazards.contains(where: { $0.rect.intersects(frame) })
        let edgeProbe = CGRect(x: frame.midX - 4, y: frame.minY - 4, width: 8, height: 6)
        let edgeSafe = platformRects.contains(where: { $0.intersects(edgeProbe) })
        safeTracker.update(candidate: player.position, isGrounded: isGrounded, isSafe: !touchingHazard, isDashing: dashController.isDashing, isWallSliding: currentWallCling != nil, edgeSafe: edgeSafe)
    }

    private func updateHazards() {
        guard recoveryLockRemaining <= 0 else { return }
        switch HazardController.event(playerFrame: playerColliderFrame(), playerY: player.position.y, layout: worldLayout) {
        case .none: return
        case .spikeDamage:
            tutorialController.register(action: .spikes)
            let safe = safeTracker.safePosition ?? CheckpointController.respawnPosition(session: session, layout: worldLayout)
            let cp = CheckpointController.respawnPosition(session: session, layout: worldLayout)
            let result = RespawnController.spikeRecovery(currentHP: currentHP, safePosition: safe, checkpointPosition: cp)
            if result.resetsEnemies { performDeathRecovery(result) }
            else {
                currentHP = result.hp; lifeController.registerDamage(isLethal: false); essenceController.cancelFocus()
                performRecovery(result)
            }
        case .death:
            tutorialController.register(action: .pit)
            let result = RespawnController.deathRecovery(checkpointPosition: CheckpointController.respawnPosition(session: session, layout: worldLayout), maxHP: maxHP)
            lifeController.registerDamage(isLethal: true)
            performDeathRecovery(result)
        }
    }

    private func performRecovery(_ result: RecoveryResult) {
        recoveryLockRemaining = result.transitionDuration
        velocity = .zero; targetMoveInput = 0; moveInput = 0
        player.position = result.position
        damageController.grantInvulnerability(result.invulnerability)
        safeTracker.reset(to: result.position)
        flashRecovery(duration: result.transitionDuration)
        gameCamera.position = cameraController.reset(playerPosition: player.position, viewportSize: size, zoom: cameraZoom, worldBounds: worldLayout.worldBounds)
    }

    private func performDeathRecovery(_ result: RecoveryResult) {
        currentHP = result.hp
        session.preserveAcrossDeathResetEnemies(worldLayout.enemies)
        resetEnemyControllersFromSession()
        lifeController.respawn()
        performRecovery(result)
    }

    private func flashRecovery(duration: TimeInterval) {
        recoveryOverlay.removeAllActions()
        recoveryOverlay.alpha = 0
        recoveryOverlay.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.88, duration: min(0.18, duration * 0.4)),
            SKAction.wait(forDuration: max(0.02, duration * 0.25)),
            SKAction.fadeOut(withDuration: max(0.12, duration * 0.35))
        ]))
    }

    private func updateCheckpoints() {
        for cp in worldLayout.checkpoints where hypot(player.position.x - cp.position.x, player.position.y - cp.position.y) < 95 {
            guard session.activeCheckpointID != cp.id else { continue }
            let state = PlayerResourceState(hp: currentHP, maxHP: maxHP, light: essenceController.essence)
            if let result = CheckpointController.activate(id: cp.id, playerState: state, session: session, layout: worldLayout) {
                currentHP = result.player.hp
                worldNodes[cp.id]?.run(SKAction.repeat(SKAction.sequence([.fadeAlpha(to: 0.45, duration: 0.12), .fadeAlpha(to: 1, duration: 0.12)]), count: 2))
                tutorialController.register(action: .checkpoint)
            }
        }
    }

    private func updateInteractions() {
        applyInteractionVisualState()
        if let hidden = worldLayout.interactions.first(where: { $0.kind == .hiddenPassage }), hidden.rect.insetBy(dx: -60, dy: -40).contains(player.position) {
            tutorialController.register(action: .hiddenPath)
        }
        if worldLayout.exitMarker.contains(player.position) { tutorialController.register(action: .testComplete) }
    }

    private func updateEnemies(_ dt: TimeInterval) {
        guard recoveryLockRemaining <= 0 else { return }
        for spec in worldLayout.enemies {
            guard let controller = enemyControllers[spec.id], let node = enemyNodes[spec.id] else { continue }
            let result = controller.update(dt: dt, playerPosition: player.position)
            node.position = result.position
            node.isHidden = !controller.isAlive
            session.enemyStates[spec.id] = controller.snapshot()
            guard controller.isAlive else { continue }
            let enemyFrame = node.frame.insetBy(dx: -3, dy: -3)
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
    }

    private func resetEnemyControllersFromSession() {
        for spec in worldLayout.enemies {
            let controller = TestEnemyController(spec: spec, snapshot: session.enemyStates[spec.id])
            enemyControllers[spec.id] = controller
            if let node = enemyNodes[spec.id] { node.position = controller.position; node.isHidden = !controller.isAlive }
        }
    }

    private func processAttackHits() {
        guard attackController.isHitboxActive else { return }
        let sequence = essenceController.acceptedMeleeHitSequence
        if sequence != lastAttackSequenceProcessed { lastAttackSequenceProcessed = sequence }
        let hitbox = CGRect(x: player.position.x + facing * 62 - 55, y: player.position.y - 42, width: 110, height: 84)
        for (id, controller) in enemyControllers where controller.isAlive {
            guard let node = enemyNodes[id], hitbox.intersects(node.frame) else { continue }
            let markerKey = "attack-hit-\(id)-\(attackController.attackRemaining)"
            if player.userData?[markerKey] as? Bool == true { continue }
            if player.userData == nil { player.userData = NSMutableDictionary() }
            player.userData?[markerKey] = true
            if controller.receiveMeleeHit() {
                essenceController.gainFromAcceptedMeleeHit()
                session.enemyStates[id] = controller.snapshot()
                node.run(SKAction.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeAlpha(to: 1, duration: 0.08)]))
            }
        }
        if !attackController.isAttacking { player.userData = NSMutableDictionary() }
    }

    private func updateTutorial() {
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
            case "MOVE": pulseTutorial(rightButton)
            default: break
            }
        case .world(let id):
            worldNodes[id]?.run(SKAction.sequence([.fadeAlpha(to: 0.5, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)]), withKey: "tutorialPulse")
        case .none: break
        }
    }

    private func pulseTutorial(_ button: SKShapeNode) {
        guard button.action(forKey: "tutorialPulse") == nil else { return }
        button.run(SKAction.repeatForever(SKAction.sequence([.fadeAlpha(to: 0.45, duration: 0.28), .fadeAlpha(to: 1, duration: 0.28)])), withKey: "tutorialPulse")
    }

    private func clearTutorialButtonHighlights() {
        for b in [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton] {
            b.removeAction(forKey: "tutorialPulse")
            if b.alpha < 0.4 { b.alpha = 1 }
        }
    }

    private func movePlayer(_ dt: CGFloat) {
        let totalDX = velocity.dx * dt, totalDY = velocity.dy * dt
        let steps = max(1, Int(ceil(max(abs(totalDX), abs(totalDY)) / CGFloat(tuning.maxMotionPerSubstep))))
        let stepDX = totalDX / CGFloat(steps), stepDY = totalDY / CGFloat(steps)
        var groundedDuringMove = false
        for _ in 0..<steps { moveHorizontally(stepDX); if moveVertically(stepDY) { groundedDuringMove = true } }
        if groundedDuringMove || isStandingOnSurface() { isGrounded = true; coyoteTimer = tuning.coyoteDuration; dashController.restoreAirDash() }
        else { isGrounded = false }
    }

    private func moveHorizontally(_ dx: CGFloat) {
        guard dx != 0 else { return }
        player.position.x += dx
        var frame = playerColliderFrame()
        for rect in platformRects where frame.intersects(rect) {
            player.position.x = dx > 0 ? rect.minX - colliderSize.width * 0.5 : rect.maxX + colliderSize.width * 0.5
            velocity.dx = 0; dashController.cancelActiveDash(); frame = playerColliderFrame()
        }
    }

    @discardableResult
    private func moveVertically(_ dy: CGFloat) -> Bool {
        guard dy != 0 else { return false }
        let oldFrame = playerColliderFrame(); player.position.y += dy
        var frame = playerColliderFrame(); var landed = false
        for rect in platformRects where frame.intersects(rect) {
            if dy < 0 && oldFrame.minY >= rect.maxY - 1 {
                player.position.y = rect.maxY + colliderSize.height * 0.5; velocity.dy = 0; landed = true; frame = playerColliderFrame()
            } else if dy > 0 && oldFrame.maxY <= rect.minY + 1 {
                player.position.y = rect.minY - colliderSize.height * 0.5; velocity.dy = 0; frame = playerColliderFrame()
            }
        }
        return landed
    }

    private func playerColliderFrame(at position: CGPoint? = nil) -> CGRect {
        let p = position ?? player.position
        return CGRect(x: p.x - colliderSize.width * 0.5, y: p.y - colliderSize.height * 0.5, width: colliderSize.width, height: colliderSize.height)
    }

    private func isStandingOnSurface() -> Bool {
        if velocity.dy > 1 { return false }
        let probe = playerColliderFrame(at: CGPoint(x: player.position.x, y: player.position.y - 2))
        return platformRects.contains { probe.intersects($0) }
    }

    private func wallContactSide() -> WallSide? {
        let frame = playerColliderFrame(), inset: CGFloat = 7
        let leftProbe = CGRect(x: frame.minX - 3, y: frame.minY + inset, width: 4, height: max(1, frame.height - inset * 2))
        let rightProbe = CGRect(x: frame.maxX - 1, y: frame.minY + inset, width: 4, height: max(1, frame.height - inset * 2))
        if platformRects.contains(where: { leftProbe.intersects($0) }) { return .left }
        if platformRects.contains(where: { rightProbe.intersects($0) }) { return .right }
        return nil
    }

    private func updatePlayerVisuals(_ dt: CGFloat) {
        guard let sprite = playerSprite else { return }
        sprite.xScale = facing >= 0 ? 1 : -1
        let next: PlayerAnimationKey
        switch lifeController.state {
        case .dead: next = .death
        case .hurt: next = .hurt
        case .normal:
            if attackController.isAttacking { next = activeAttackAnimation }
            else if dashController.isDashing { next = .dash }
            else if currentWallCling != nil { next = .fall }
            else if !isGrounded { next = velocity.dy > 35 ? .jump : .fall }
            else if abs(velocity.dx) > 20 { next = .run }
            else { next = .idle }
        }
        setAnimation(next)
        let speedRatio = min(abs(velocity.dx) / CGFloat(tuning.runSpeed), 1)
        let targetRotation: CGFloat = currentWallCling != nil ? facing * 0.06 : -facing * speedRatio * 0.025
        playerVisual.zRotation += (targetRotation - playerVisual.zRotation) * min(1, dt * 10)
        playerVisual.alpha = damageController.isInvulnerable && Int(lastUpdateTime * 12) % 2 == 0 ? 0.35 : 1
    }

    private func setAnimation(_ key: PlayerAnimationKey, force: Bool = false) {
        guard let sprite = playerSprite, force || currentAnimation != key else { return }
        let frames = animationLibrary.frames(for: key); guard let first = frames.first else { return }
        currentAnimation = key; sprite.removeAction(forKey: "playerAnimation"); sprite.texture = first
        guard frames.count > 1 else { return }
        let animate = SKAction.animate(with: frames, timePerFrame: animationLibrary.frameDuration(for: key), resize: false, restore: false)
        sprite.run(animationLibrary.loops(key) ? SKAction.repeatForever(animate) : animate, withKey: "playerAnimation")
    }

    private func updateCamera(_ dt: CGFloat) {
        gameCamera.position = cameraController.update(playerPosition: player.position, velocity: velocity, facing: facing, dt: dt, viewportSize: size, zoom: cameraZoom, worldBounds: worldLayout.worldBounds)
    }

    private func updateHUDStatus() {
        let wallText = currentWallCling == nil ? "" : " • WALL"
        statusLabel.text = "HP \(currentHP)/\(maxHP) • LIGHT \(essenceController.essence)/\(essenceController.maxEssence)\(wallText)"
        healButton.alpha = essenceController.essence >= essenceController.healCost && currentHP < maxHP ? 1 : 0.45
        dashButton.alpha = dashController.cooldownRemaining <= 0 ? 1 : 0.5
    }

    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: !leftTouches.isEmpty); animateButton(rightButton, pressed: !rightTouches.isEmpty); animateButton(jumpButton, pressed: !jumpTouches.isEmpty)
    }

    private func animateButton(_ button: SKShapeNode, pressed: Bool) {
        button.removeAction(forKey: "press")
        let action = SKAction.group([SKAction.scale(to: pressed ? 0.9 : 1, duration: 0.08), SKAction.fadeAlpha(to: pressed ? 0.82 : 1, duration: 0.08)])
        action.timingMode = .easeOut; button.run(action, withKey: "press")
    }

    private func pulse(_ button: SKShapeNode) {
        button.run(SKAction.sequence([SKAction.scale(to: 0.86, duration: 0.04), SKAction.scale(to: 1, duration: 0.09)]), withKey: "tap")
    }

    private func moveToward(_ current: CGFloat, _ target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        if abs(target - current) <= maxDelta { return target }
        return current + (target > current ? maxDelta : -maxDelta)
    }
}
