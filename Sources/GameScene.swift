import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum Control {
        case left
        case right
        case attack
        case jump
    }

    private enum PlayerAnimationState {
        case idle
        case run
        case jumpRise
        case fall
        case land
        case attack
    }

    // MARK: - Scene graph

    private let worldRoot = SKNode()
    private let player = SKNode()
    private let playerVisual = SKShapeNode(
        rectOf: CGSize(width: 42, height: 64),
        cornerRadius: 10
    )
    private let attackHitboxVisual = SKShapeNode(
        rectOf: CGSize(width: 62, height: 42),
        cornerRadius: 8
    )

    private let testEnemy = SKNode()
    private let enemyVisual = SKShapeNode(
        rectOf: CGSize(width: 44, height: 62),
        cornerRadius: 9
    )
    private let enemyHPBackground = SKSpriteNode(
        color: UIColor(white: 0.08, alpha: 0.88),
        size: CGSize(width: 54, height: 8)
    )
    private let enemyHPFill = SKSpriteNode(
        color: UIColor(red: 0.92, green: 0.25, blue: 0.20, alpha: 1),
        size: CGSize(width: 50, height: 5)
    )
    private let enemyHPLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let gameCamera = SKCameraNode()
    private let hud = SKNode()

    // MARK: - Kinematic collision model

    private let colliderSize = CGSize(width: 36, height: 60)
    private var platformRects: [CGRect] = []
    private var worldWidth: CGFloat = 2600

    private var velocity = CGVector.zero
    private var isGrounded = false
    private var lastUpdateTime: TimeInterval = 0

    private let gravity: CGFloat = -1700
    private let jumpVelocity: CGFloat = 610
    private let jumpReleaseVelocity: CGFloat = 285
    private let maxFallSpeed: CGFloat = -900
    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1900
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2400

    private let coyoteDuration: TimeInterval = 0.12
    private let jumpBufferDuration: TimeInterval = 0.12
    private var coyoteRemaining: TimeInterval = 0
    private var jumpBufferRemaining: TimeInterval = 0
    private var bufferedJumpWasReleased = false

    // Small motion substeps keep the controller from tunnelling through platforms.
    private let maxMotionPerSubstep: CGFloat = 5

    // MARK: - Input

    private var activeControls: [ObjectIdentifier: Control] = [:]
    private var moveInput: CGFloat = 0
    private var smoothedMoveInput: CGFloat = 0
    private var facing: CGFloat = 1

    // MARK: - Combat

    private var attackController = AttackController()
    private var attackFacing: CGFloat = 1
    private var attackSequenceID = 0
    private let attackHitboxSize = CGSize(width: 62, height: 42)
    private let attackHitboxOffset: CGFloat = 50

    // MARK: - Test enemy

    private var enemyHealth = EnemyHealth(maxHP: 3)
    private let enemyColliderSize = CGSize(width: 40, height: 60)
    private var enemyHitFlashRemaining: CGFloat = 0

    // MARK: - Temporary player animation state machine

    private var animationState: PlayerAnimationState = .idle
    private var animationStateTime: CGFloat = 0
    private var landedThisFrame = false
    private let landingStateDuration: CGFloat = 0.11

    // MARK: - Camera

    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 5.0
    private let cameraLookAhead: CGFloat = 95
    private let cameraVerticalOffset: CGFloat = 12

    // MARK: - HUD

    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let attackButton = SKShapeNode(circleOfRadius: 47)
    private let jumpButton = SKShapeNode(circleOfRadius: 51)

    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let attackLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let jumpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        resetSceneGraph()

        backgroundColor = UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        buildWorld()
        buildPlayer()
        buildTestEnemy()
        buildCamera()
        buildHUD()
        layoutHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func resetSceneGraph() {
        camera = nil
        removeAllChildren()
        worldRoot.removeAllChildren()

        player.removeAllChildren()
        player.removeAllActions()
        playerVisual.removeAllChildren()
        playerVisual.removeAllActions()
        attackHitboxVisual.removeAllActions()

        testEnemy.removeAllChildren()
        testEnemy.removeAllActions()
        enemyVisual.removeAllChildren()
        enemyVisual.removeAllActions()
        enemyHPBackground.removeAllActions()
        enemyHPFill.removeAllActions()
        enemyHPLabel.removeAllActions()

        gameCamera.removeAllChildren()
        gameCamera.removeAllActions()
        hud.removeAllChildren()

        platformRects.removeAll(keepingCapacity: true)
        activeControls.removeAll(keepingCapacity: true)
        velocity = .zero
        isGrounded = true
        lastUpdateTime = 0
        coyoteRemaining = coyoteDuration
        jumpBufferRemaining = 0
        bufferedJumpWasReleased = false
        moveInput = 0
        smoothedMoveInput = 0
        facing = 1
        attackFacing = 1
        attackSequenceID = 0
        attackController.reset()
        enemyHealth = EnemyHealth(maxHP: 3)
        enemyHitFlashRemaining = 0
        animationState = .idle
        animationStateTime = 0
        landedThisFrame = false
    }

    // MARK: - World

    private func buildWorld() {
        worldRoot.name = "worldRoot"
        addChild(worldRoot)

        worldWidth = max(2600, size.width * 3.2)

        let backdropHeight = max(size.height, 560)
        let backdrop = SKShapeNode(
            rectOf: CGSize(width: worldWidth, height: backdropHeight)
        )
        backdrop.fillColor = UIColor(red: 0.035, green: 0.042, blue: 0.06, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldWidth * 0.5, y: backdropHeight * 0.5)
        backdrop.zPosition = -100
        worldRoot.addChild(backdrop)

        for index in 0..<14 {
            let pillar = SKShapeNode(
                rectOf: CGSize(
                    width: 62 + CGFloat(index % 3) * 18,
                    height: 170 + CGFloat(index % 4) * 45
                ),
                cornerRadius: 16
            )
            pillar.fillColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 0.72)
            pillar.strokeColor = .clear
            pillar.position = CGPoint(
                x: 120 + CGFloat(index) * 175,
                y: 115 + pillar.frame.height * 0.5
            )
            pillar.zPosition = -50
            worldRoot.addChild(pillar)
        }

        addPlatform(
            center: CGPoint(x: worldWidth * 0.5, y: 60),
            size: CGSize(width: worldWidth, height: 80)
        )
        addPlatform(center: CGPoint(x: 520, y: 190), size: CGSize(width: 260, height: 28))
        addPlatform(center: CGPoint(x: 900, y: 255), size: CGSize(width: 230, height: 28))
        addPlatform(center: CGPoint(x: 1320, y: 175), size: CGSize(width: 310, height: 28))
        addPlatform(center: CGPoint(x: 1740, y: 235), size: CGSize(width: 260, height: 28))
    }

    private func addPlatform(center: CGPoint, size: CGSize) {
        platformRects.append(
            CGRect(
                x: center.x - size.width * 0.5,
                y: center.y - size.height * 0.5,
                width: size.width,
                height: size.height
            )
        )

        let visual = SKShapeNode(rectOf: size, cornerRadius: 7)
        visual.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        visual.strokeColor = UIColor(white: 0.42, alpha: 0.35)
        visual.lineWidth = 2
        visual.position = center
        visual.zPosition = 1
        worldRoot.addChild(visual)
    }

    // MARK: - Player

    private func buildPlayer() {
        player.name = "player"
        player.position = CGPoint(x: 230, y: 130)
        player.zPosition = 50

        playerVisual.fillColor = UIColor(red: 0.78, green: 0.82, blue: 0.9, alpha: 1)
        playerVisual.strokeColor = UIColor(white: 1, alpha: 0.22)
        playerVisual.lineWidth = 2
        playerVisual.position = .zero
        playerVisual.xScale = 1
        playerVisual.yScale = 1
        playerVisual.zRotation = 0

        let face = SKShapeNode(rectOf: CGSize(width: 20, height: 6), cornerRadius: 3)
        face.fillColor = UIColor(red: 0.48, green: 0.82, blue: 1, alpha: 1)
        face.strokeColor = .clear
        face.position = CGPoint(x: 5, y: 10)
        face.name = "face"
        playerVisual.addChild(face)

        let leftFoot = SKShapeNode(rectOf: CGSize(width: 14, height: 8), cornerRadius: 3)
        leftFoot.fillColor = UIColor(red: 0.48, green: 0.54, blue: 0.66, alpha: 1)
        leftFoot.strokeColor = .clear
        leftFoot.position = CGPoint(x: -9, y: -30)
        leftFoot.name = "leftFoot"
        playerVisual.addChild(leftFoot)

        let rightFoot = SKShapeNode(rectOf: CGSize(width: 14, height: 8), cornerRadius: 3)
        rightFoot.fillColor = UIColor(red: 0.48, green: 0.54, blue: 0.66, alpha: 1)
        rightFoot.strokeColor = .clear
        rightFoot.position = CGPoint(x: 9, y: -30)
        rightFoot.name = "rightFoot"
        playerVisual.addChild(rightFoot)

        let blade = SKShapeNode(rectOf: CGSize(width: 36, height: 5), cornerRadius: 2)
        blade.fillColor = UIColor(white: 0.96, alpha: 0.95)
        blade.strokeColor = .clear
        blade.position = CGPoint(x: 30, y: 4)
        blade.alpha = 0
        blade.name = "attackBlade"
        playerVisual.addChild(blade)

        let glow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 14))
        glow.fillColor = UIColor(red: 0.35, green: 0.7, blue: 1, alpha: 0.1)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: -35)
        glow.zPosition = -1
        glow.name = "glow"
        playerVisual.addChild(glow)

        attackHitboxVisual.fillColor = UIColor(red: 1.0, green: 0.34, blue: 0.20, alpha: 0.24)
        attackHitboxVisual.strokeColor = UIColor(red: 1.0, green: 0.58, blue: 0.42, alpha: 0.8)
        attackHitboxVisual.lineWidth = 2
        attackHitboxVisual.position = CGPoint(x: attackHitboxOffset, y: 2)
        attackHitboxVisual.zPosition = 60
        attackHitboxVisual.alpha = 0
        attackHitboxVisual.name = "attackHitbox"

        player.addChild(attackHitboxVisual)
        player.addChild(playerVisual)
        addChild(player)
    }

    private var playerRect: CGRect {
        CGRect(
            x: player.position.x - colliderSize.width * 0.5,
            y: player.position.y - colliderSize.height * 0.5,
            width: colliderSize.width,
            height: colliderSize.height
        )
    }

    /// Scene-space damage rectangle for the active melee damage window.
    private var currentAttackHitbox: CGRect? {
        guard attackController.isHitboxActive else { return nil }
        let centerX = player.position.x + attackFacing * attackHitboxOffset
        return CGRect(
            x: centerX - attackHitboxSize.width * 0.5,
            y: player.position.y - attackHitboxSize.height * 0.5 + 2,
            width: attackHitboxSize.width,
            height: attackHitboxSize.height
        )
    }

    // MARK: - Test enemy

    private func buildTestEnemy() {
        testEnemy.name = "testEnemy"
        testEnemy.position = CGPoint(x: 400, y: 130)
        testEnemy.zPosition = 45
        testEnemy.alpha = 1
        testEnemy.setScale(1)
        testEnemy.isHidden = false

        enemyVisual.fillColor = UIColor(red: 0.56, green: 0.20, blue: 0.23, alpha: 1)
        enemyVisual.strokeColor = UIColor(red: 0.95, green: 0.45, blue: 0.38, alpha: 0.55)
        enemyVisual.lineWidth = 2
        enemyVisual.position = .zero
        enemyVisual.alpha = 1

        let eye = SKShapeNode(rectOf: CGSize(width: 21, height: 6), cornerRadius: 3)
        eye.fillColor = UIColor(red: 1.0, green: 0.48, blue: 0.34, alpha: 1)
        eye.strokeColor = .clear
        eye.position = CGPoint(x: -3, y: 9)
        enemyVisual.addChild(eye)

        enemyHPBackground.position = CGPoint(x: 0, y: 43)
        enemyHPBackground.zPosition = 4

        enemyHPFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        enemyHPFill.position = CGPoint(x: -25, y: 43)
        enemyHPFill.zPosition = 5
        enemyHPFill.xScale = 1

        enemyHPLabel.text = "HP 3/3"
        enemyHPLabel.fontSize = 11
        enemyHPLabel.fontColor = UIColor(white: 0.96, alpha: 0.9)
        enemyHPLabel.horizontalAlignmentMode = .center
        enemyHPLabel.verticalAlignmentMode = .center
        enemyHPLabel.position = CGPoint(x: 0, y: 57)
        enemyHPLabel.zPosition = 6

        testEnemy.addChild(enemyVisual)
        testEnemy.addChild(enemyHPBackground)
        testEnemy.addChild(enemyHPFill)
        testEnemy.addChild(enemyHPLabel)
        addChild(testEnemy)

        updateEnemyHealthHUD()
    }

    private var enemyRect: CGRect {
        CGRect(
            x: testEnemy.position.x - enemyColliderSize.width * 0.5,
            y: testEnemy.position.y - enemyColliderSize.height * 0.5,
            width: enemyColliderSize.width,
            height: enemyColliderSize.height
        )
    }

    private func resolveAttackHitOnEnemy() {
        guard enemyHealth.isAlive,
              let hitbox = currentAttackHitbox,
              hitbox.intersects(enemyRect) else {
            return
        }

        guard enemyHealth.applyHit(damage: 1, attackID: attackSequenceID) else {
            return
        }

        enemyHitFlashRemaining = 0.11
        updateEnemyHealthHUD()

        if !enemyHealth.isAlive {
            enemyHPLabel.text = "DEAD"
            let fade = SKAction.fadeOut(withDuration: 0.24)
            let shrink = SKAction.scale(to: 0.76, duration: 0.24)
            let death = SKAction.group([fade, shrink])
            death.timingMode = .easeIn
            testEnemy.run(death, withKey: "death")
        }
    }

    private func updateEnemyHealthHUD() {
        let ratio = CGFloat(enemyHealth.hp) / CGFloat(enemyHealth.maxHP)
        enemyHPFill.xScale = max(0, ratio)
        enemyHPLabel.text = "HP \(enemyHealth.hp)/\(enemyHealth.maxHP)"
    }

    private func updateEnemyPresentation(_ dt: CGFloat) {
        guard enemyHealth.isAlive else { return }

        enemyHitFlashRemaining = max(0, enemyHitFlashRemaining - dt)
        if enemyHitFlashRemaining > 0 {
            enemyVisual.fillColor = UIColor(red: 1.0, green: 0.54, blue: 0.28, alpha: 1)
        } else {
            enemyVisual.fillColor = UIColor(red: 0.56, green: 0.20, blue: 0.23, alpha: 1)
        }
    }

    // MARK: - Camera / HUD

    private func buildCamera() {
        addChild(gameCamera)
        camera = gameCamera
        gameCamera.setScale(cameraZoom)

        let halfVisibleWidth = size.width * 0.5 * cameraZoom
        let startX = max(halfVisibleWidth, player.position.x + 100)
        gameCamera.position = CGPoint(
            x: startX,
            y: size.height * 0.5 + cameraVerticalOffset
        )
    }

    private func buildHUD() {
        gameCamera.addChild(hud)
        hud.zPosition = 1000

        configureButton(leftButton)
        configureButton(rightButton)
        configureButton(attackButton)
        configureButton(jumpButton)

        leftArrow.text = "‹"
        leftArrow.fontSize = 50
        leftArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        leftArrow.verticalAlignmentMode = .center
        leftArrow.horizontalAlignmentMode = .center

        rightArrow.text = "›"
        rightArrow.fontSize = 50
        rightArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        rightArrow.verticalAlignmentMode = .center
        rightArrow.horizontalAlignmentMode = .center

        attackLabel.text = "ATTACK"
        attackLabel.fontSize = 12
        attackLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)
        attackLabel.verticalAlignmentMode = .center
        attackLabel.horizontalAlignmentMode = .center

        jumpLabel.text = "JUMP"
        jumpLabel.fontSize = 15
        jumpLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)
        jumpLabel.verticalAlignmentMode = .center
        jumpLabel.horizontalAlignmentMode = .center

        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        attackButton.addChild(attackLabel)
        jumpButton.addChild(jumpLabel)

        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(attackButton)
        hud.addChild(jumpButton)
    }

    private func configureButton(_ button: SKShapeNode) {
        button.removeAllChildren()
        button.removeAllActions()
        button.setScale(1)
        button.alpha = 1
        button.fillColor = UIColor(white: 0.12, alpha: 0.52)
        button.strokeColor = UIColor(white: 1, alpha: 0.14)
        button.lineWidth = 2
    }

    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }

        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let bottomPadding = max(76, size.height * 0.15)

        leftButton.position = CGPoint(x: -halfW + 86, y: -halfH + bottomPadding)
        rightButton.position = CGPoint(x: -halfW + 190, y: -halfH + bottomPadding)
        attackButton.position = CGPoint(x: halfW - 215, y: -halfH + bottomPadding + 2)
        jumpButton.position = CGPoint(x: halfW - 96, y: -halfH + bottomPadding + 4)
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            let control = classifyControl(at: touch.location(in: skView), in: skView)

            if let control {
                activeControls[id] = control
                handleControlPressed(control)
            }
        }

        recalculateMoveInput()
        refreshButtonVisuals()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            let oldControl = activeControls[id]
            let newControl = classifyControl(at: touch.location(in: skView), in: skView)

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

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouches(touches)
    }

    private func releaseTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if activeControls[id] == .jump {
                releaseJump()
            }
            activeControls.removeValue(forKey: id)
        }

        recalculateMoveInput()
        refreshButtonVisuals()
    }

    private func handleControlPressed(_ control: Control) {
        switch control {
        case .jump:
            queueJump()
        case .attack:
            tryAttack()
        case .left, .right:
            break
        }
    }

    private func classifyControl(at point: CGPoint, in skView: SKView) -> Control? {
        let width = skView.bounds.width
        let height = skView.bounds.height
        guard width > 0, height > 0 else { return nil }

        // UIKit/SKView touch coordinates have their origin at the top-left.
        // Hit areas are intentionally a little larger than the visible controls.
        let controlY = height * 0.80
        let candidates: [(control: Control, center: CGPoint, radius: CGFloat)] = [
            (.left, CGPoint(x: width * 0.10, y: controlY), 70),
            (.right, CGPoint(x: width * 0.225, y: controlY), 70),
            (.attack, CGPoint(x: width * 0.74, y: controlY), 76),
            (.jump, CGPoint(x: width * 0.89, y: controlY), 82)
        ]

        var best: (control: Control, distance: CGFloat)?

        for candidate in candidates {
            let distance = hypot(point.x - candidate.center.x, point.y - candidate.center.y)
            guard distance <= candidate.radius else { continue }

            if best == nil || distance < best!.distance {
                best = (candidate.control, distance)
            }
        }

        return best?.control
    }

    private func queueJump() {
        jumpBufferRemaining = jumpBufferDuration
        bufferedJumpWasReleased = false
    }

    private func releaseJump() {
        if velocity.dy > jumpReleaseVelocity {
            velocity.dy = jumpReleaseVelocity
        } else if jumpBufferRemaining > 0 {
            // A very fast tap that begins and ends between frames still produces a short hop.
            bufferedJumpWasReleased = true
        }
    }

    private func tryAttack() {
        guard attackController.tryStart() else { return }
        attackFacing = facing
        attackSequenceID += 1
        animationState = .attack
        animationStateTime = 0
    }

    private func recalculateMoveInput() {
        var leftHeld = false
        var rightHeld = false

        for control in activeControls.values {
            if control == .left { leftHeld = true }
            if control == .right { rightHeld = true }
        }

        moveInput = (leftHeld ? -1 : 0) + (rightHeld ? 1 : 0)
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(max(currentTime - lastUpdateTime, 0), 1.0 / 30.0)
        }
        lastUpdateTime = currentTime

        attackController.update(dt)
        updateTimers(dt)
        consumeBufferedJumpIfPossible()
        updateHorizontalVelocity(CGFloat(dt))

        velocity.dy = max(maxFallSpeed, velocity.dy + gravity * CGFloat(dt))
        integrateKinematicMotion(CGFloat(dt))

        resolveAttackHitOnEnemy()
        updateEnemyPresentation(CGFloat(dt))
        updateAnimationState(CGFloat(dt))
        updatePlayerVisuals(CGFloat(dt))
        updateAttackHitboxVisual()
        updateCamera(CGFloat(dt))
    }

    private func updateTimers(_ dt: TimeInterval) {
        jumpBufferRemaining = max(0, jumpBufferRemaining - dt)

        if isGrounded {
            coyoteRemaining = coyoteDuration
        } else {
            coyoteRemaining = max(0, coyoteRemaining - dt)
        }
    }

    private func consumeBufferedJumpIfPossible() {
        guard jumpBufferRemaining > 0, coyoteRemaining > 0 else { return }

        velocity.dy = bufferedJumpWasReleased ? jumpReleaseVelocity : jumpVelocity
        isGrounded = false
        coyoteRemaining = 0
        jumpBufferRemaining = 0
        bufferedJumpWasReleased = false
    }

    private func updateHorizontalVelocity(_ dt: CGFloat) {
        let response: CGFloat = 12
        smoothedMoveInput += (moveInput - smoothedMoveInput) * min(1, response * dt)

        let targetVX = smoothedMoveInput * runSpeed
        let hasInput = abs(moveInput) > 0.01
        let acceleration = hasInput
            ? (isGrounded ? groundAcceleration : airAcceleration)
            : (isGrounded ? groundDeceleration : airAcceleration * 0.5)

        velocity.dx = moveToward(
            velocity.dx,
            targetVX,
            maxDelta: acceleration * dt
        )

        if !hasInput && abs(velocity.dx) < 2 {
            velocity.dx = 0
        }

        if abs(moveInput) > 0.01 {
            facing = moveInput > 0 ? 1 : -1
        }
    }

    private func integrateKinematicMotion(_ dt: CGFloat) {
        let totalDX = velocity.dx * dt
        let totalDY = velocity.dy * dt
        let maxDistance = max(abs(totalDX), abs(totalDY))
        let steps = max(1, Int(ceil(maxDistance / maxMotionPerSubstep)))
        let stepDX = totalDX / CGFloat(steps)
        let stepDY = totalDY / CGFloat(steps)

        let wasGrounded = isGrounded
        landedThisFrame = false
        isGrounded = false

        for _ in 0..<steps {
            moveHorizontally(stepDX)
            moveVertically(stepDY)
        }

        if isGrounded && !wasGrounded {
            landedThisFrame = true
        }

        let halfW = colliderSize.width * 0.5
        if player.position.x < halfW {
            player.position.x = halfW
            velocity.dx = max(0, velocity.dx)
        }
        if player.position.x > worldWidth - halfW {
            player.position.x = worldWidth - halfW
            velocity.dx = min(0, velocity.dx)
        }
    }

    private func moveHorizontally(_ amount: CGFloat) {
        guard amount != 0 else { return }

        player.position.x += amount
        var rect = playerRect
        let halfW = colliderSize.width * 0.5

        for platform in platformRects where rect.intersects(platform) {
            if amount > 0 {
                player.position.x = platform.minX - halfW
            } else {
                player.position.x = platform.maxX + halfW
            }
            velocity.dx = 0
            rect = playerRect
        }
    }

    private func moveVertically(_ amount: CGFloat) {
        guard amount != 0 else { return }

        player.position.y += amount
        var rect = playerRect
        let halfH = colliderSize.height * 0.5

        for platform in platformRects where rect.intersects(platform) {
            if amount < 0 {
                player.position.y = platform.maxY + halfH
                velocity.dy = 0
                isGrounded = true
            } else {
                player.position.y = platform.minY - halfH
                velocity.dy = 0
            }
            rect = playerRect
        }
    }

    // MARK: - Presentation

    private func updateCamera(_ dt: CGFloat) {
        let visibleHalfWidth = size.width * 0.5 * cameraZoom
        let speedFactor = min(abs(velocity.dx) / runSpeed, 1)
        let direction: CGFloat = abs(velocity.dx) > 5
            ? (velocity.dx > 0 ? 1 : -1)
            : facing

        let targetXUnclamped = player.position.x + direction * cameraLookAhead * speedFactor
        let minX = visibleHalfWidth
        let maxX = max(minX, worldWidth - visibleHalfWidth)
        let targetX = max(minX, min(maxX, targetXUnclamped))
        let follow = min(1, cameraFollowSpeed * dt)
        gameCamera.position.x += (targetX - gameCamera.position.x) * follow

        let baseY = size.height * 0.5 + cameraVerticalOffset
        let relativeY = player.position.y - 150
        let targetY = baseY + max(-30, min(80, relativeY * 0.20))
        gameCamera.position.y += (targetY - gameCamera.position.y) * min(1, 3.2 * dt)
    }

    private func updateAnimationState(_ dt: CGFloat) {
        animationStateTime += dt

        let nextState: PlayerAnimationState
        if attackController.isAttacking {
            nextState = .attack
        } else if landedThisFrame {
            nextState = .land
        } else if !isGrounded {
            nextState = velocity.dy > 18 ? .jumpRise : .fall
        } else if abs(velocity.dx) > 20 || abs(moveInput) > 0.01 {
            nextState = .run
        } else {
            nextState = .idle
        }

        if animationState == .land,
           animationStateTime < landingStateDuration,
           isGrounded,
           nextState != .attack,
           nextState != .jumpRise,
           nextState != .fall {
            return
        }

        if nextState != animationState {
            animationState = nextState
            animationStateTime = 0
        }
    }

    private func updatePlayerVisuals(_ dt: CGFloat) {
        let speedRatio = min(abs(velocity.dx) / runSpeed, 1)
        let presentationFacing = attackController.isAttacking ? attackFacing : facing

        var targetScaleX: CGFloat = 1
        var targetScaleY: CGFloat = 1
        var targetVisualY: CGFloat = 0
        var targetRotation: CGFloat = 0

        var leftFootTarget = CGPoint(x: -9, y: -30)
        var rightFootTarget = CGPoint(x: 9, y: -30)
        var leftFootRotation: CGFloat = 0
        var rightFootRotation: CGFloat = 0
        var bladeAlpha: CGFloat = 0
        var bladePosition = CGPoint(x: presentationFacing * 30, y: 4)
        var bladeRotation: CGFloat = 0

        switch animationState {
        case .idle:
            let breath = sin(animationStateTime * 3.2)
            targetScaleX = 1 - breath * 0.006
            targetScaleY = 1 + breath * 0.012
            targetVisualY = breath * 0.8

        case .run:
            let phase = animationStateTime * (10 + 6 * speedRatio)
            let stride = sin(phase)
            let bounce = abs(sin(phase))
            targetScaleX = 1 + bounce * 0.012
            targetScaleY = 1 - bounce * 0.014
            targetVisualY = bounce * 1.8
            targetRotation = -facing * 0.045 * speedRatio

            leftFootTarget.y = -30 + max(0, stride) * 3
            rightFootTarget.y = -30 + max(0, -stride) * 3
            leftFootTarget.x = -9 + stride * 2.4
            rightFootTarget.x = 9 - stride * 2.4
            leftFootRotation = stride * 0.32
            rightFootRotation = -stride * 0.32

        case .jumpRise:
            targetScaleX = 0.94
            targetScaleY = 1.06
            targetVisualY = 1.5
            targetRotation = -facing * 0.025
            leftFootTarget = CGPoint(x: -7, y: -27)
            rightFootTarget = CGPoint(x: 7, y: -27)
            leftFootRotation = 0.18
            rightFootRotation = -0.18

        case .fall:
            targetScaleX = 1.04
            targetScaleY = 0.97
            targetVisualY = -0.6
            targetRotation = facing * 0.018
            leftFootTarget = CGPoint(x: -10, y: -31)
            rightFootTarget = CGPoint(x: 10, y: -31)
            leftFootRotation = -0.08
            rightFootRotation = 0.08

        case .land:
            let progress = min(animationStateTime / landingStateDuration, 1)
            let squash = 1 - progress
            targetScaleX = 1 + 0.10 * squash
            targetScaleY = 1 - 0.12 * squash
            targetVisualY = -2.2 * squash
            leftFootTarget = CGPoint(x: -10, y: -29)
            rightFootTarget = CGPoint(x: 10, y: -29)

        case .attack:
            let duration = max(CGFloat(attackController.attackDuration), 0.001)
            let progress = min(animationStateTime / duration, 1)
            let swing: CGFloat

            if progress < 0.24 {
                swing = -0.65 * (progress / 0.24)
            } else if progress < 0.62 {
                swing = -0.65 + 1.55 * ((progress - 0.24) / 0.38)
            } else {
                swing = 0.90 * (1 - ((progress - 0.62) / 0.38))
            }

            targetScaleX = 1.04
            targetScaleY = 0.98
            targetVisualY = isGrounded ? 0.4 : 1.0
            targetRotation = attackFacing * swing * 0.18
            bladeAlpha = 1
            bladePosition = CGPoint(x: attackFacing * 31, y: 5)
            bladeRotation = -attackFacing * swing * 0.72

            if isGrounded {
                leftFootTarget = CGPoint(x: -10 - attackFacing * 2, y: -30)
                rightFootTarget = CGPoint(x: 10 + attackFacing * 2, y: -30)
            } else {
                leftFootTarget = CGPoint(x: -8, y: -27)
                rightFootTarget = CGPoint(x: 8, y: -28)
            }
        }

        let bodyBlend = min(1, dt * 15)
        playerVisual.xScale += (targetScaleX - playerVisual.xScale) * bodyBlend
        playerVisual.yScale += (targetScaleY - playerVisual.yScale) * bodyBlend
        playerVisual.position.y += (targetVisualY - playerVisual.position.y) * bodyBlend
        playerVisual.zRotation += (targetRotation - playerVisual.zRotation) * min(1, dt * 13)

        if let face = playerVisual.childNode(withName: "face") {
            let targetX = presentationFacing * 5
            face.position.x += (targetX - face.position.x) * min(1, dt * 16)
        }

        if let leftFoot = playerVisual.childNode(withName: "leftFoot") {
            leftFoot.position.x += (leftFootTarget.x - leftFoot.position.x) * min(1, dt * 18)
            leftFoot.position.y += (leftFootTarget.y - leftFoot.position.y) * min(1, dt * 18)
            leftFoot.zRotation += (leftFootRotation - leftFoot.zRotation) * min(1, dt * 18)
        }

        if let rightFoot = playerVisual.childNode(withName: "rightFoot") {
            rightFoot.position.x += (rightFootTarget.x - rightFoot.position.x) * min(1, dt * 18)
            rightFoot.position.y += (rightFootTarget.y - rightFoot.position.y) * min(1, dt * 18)
            rightFoot.zRotation += (rightFootRotation - rightFoot.zRotation) * min(1, dt * 18)
        }

        if let blade = playerVisual.childNode(withName: "attackBlade") {
            blade.position.x += (bladePosition.x - blade.position.x) * min(1, dt * 28)
            blade.position.y += (bladePosition.y - blade.position.y) * min(1, dt * 28)
            blade.zRotation += (bladeRotation - blade.zRotation) * min(1, dt * 30)
            blade.alpha += (bladeAlpha - blade.alpha) * min(1, dt * 30)
        }

        if let glow = playerVisual.childNode(withName: "glow") {
            let targetGlowScale: CGFloat = isGrounded ? 1 : 0.78
            glow.xScale += (targetGlowScale - glow.xScale) * min(1, dt * 10)
            glow.alpha += ((isGrounded ? 1 : 0.45) - glow.alpha) * min(1, dt * 10)
        }
    }

    private func updateAttackHitboxVisual() {
        attackHitboxVisual.position = CGPoint(x: attackFacing * attackHitboxOffset, y: 2)
        attackHitboxVisual.alpha = attackController.isHitboxActive ? 1 : 0
    }

    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: activeControls.values.contains(.left))
        animateButton(rightButton, pressed: activeControls.values.contains(.right))
        animateButton(attackButton, pressed: activeControls.values.contains(.attack))
        animateButton(jumpButton, pressed: activeControls.values.contains(.jump))
    }

    private func animateButton(_ button: SKShapeNode, pressed: Bool) {
        button.removeAction(forKey: "press")
        let scale: CGFloat = pressed ? 0.90 : 1
        let alpha: CGFloat = pressed ? 0.82 : 1
        let action = SKAction.group([
            SKAction.scale(to: scale, duration: 0.06),
            SKAction.fadeAlpha(to: alpha, duration: 0.06)
        ])
        action.timingMode = .easeOut
        button.run(action, withKey: "press")
    }

    private func moveToward(_ current: CGFloat, _ target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        if abs(target - current) <= maxDelta {
            return target
        }
        return current + (target > current ? maxDelta : -maxDelta)
    }
}
