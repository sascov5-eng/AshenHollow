import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum Control {
        case left
        case right
        case jump
    }

    // MARK: - Scene graph

    private let worldRoot = SKNode()
    private let player = SKNode()
    private let playerVisual = SKShapeNode(
        rectOf: CGSize(width: 42, height: 64),
        cornerRadius: 10
    )
    private let gameCamera = SKCameraNode()
    private let hud = SKNode()

    // MARK: - Kinematic collision model

    private let colliderSize = CGSize(width: 36, height: 60)
    private var platformRects: [CGRect] = []
    private var worldWidth: CGFloat = 2600

    private var velocity = CGVector.zero
    private var isGrounded = false
    private var lastUpdateTime: TimeInterval = 0
    private var frameCollisionCount = 0

    private let gravity: CGFloat = -1700
    private let jumpVelocity: CGFloat = 610
    private let maxFallSpeed: CGFloat = -900
    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1900
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2400

    private let coyoteDuration: TimeInterval = 0.12
    private let jumpBufferDuration: TimeInterval = 0.12
    private var coyoteRemaining: TimeInterval = 0
    private var jumpBufferRemaining: TimeInterval = 0

    // Small substeps prevent tunnelling through thin platforms even after a long frame.
    private let maxMotionPerSubstep: CGFloat = 5

    // MARK: - Input

    private var activeControls: [ObjectIdentifier: Control] = [:]
    private var moveInput: CGFloat = 0
    private var smoothedMoveInput: CGFloat = 0
    private var facing: CGFloat = 1
    private var touchCounter = 0
    private var jumpCounter = 0

    // MARK: - Camera

    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 5.0
    private let cameraLookAhead: CGFloat = 95
    private let cameraVerticalOffset: CGFloat = 12

    // MARK: - HUD

    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let jumpButton = SKShapeNode(circleOfRadius: 51)

    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let jumpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let buildLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let debugModeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugYLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugVYLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugGroundLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugCoyoteLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugBufferLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugCollisionLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugTouchLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        resetSceneGraph()

        backgroundColor = UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        buildWorld()
        buildPlayer()
        buildCamera()
        buildHUD()
        layoutHUD()
        updateDebugHUD()
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
        moveInput = 0
        smoothedMoveInput = 0
        facing = 1
        frameCollisionCount = 0
        touchCounter = 0
        jumpCounter = 0
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

        // All collision geometry is stored explicitly as scene-space rectangles.
        addPlatform(center: CGPoint(x: worldWidth * 0.5, y: 60), size: CGSize(width: worldWidth, height: 80))
        addPlatform(center: CGPoint(x: 520, y: 190), size: CGSize(width: 260, height: 28))
        addPlatform(center: CGPoint(x: 900, y: 255), size: CGSize(width: 230, height: 28))
        addPlatform(center: CGPoint(x: 1320, y: 175), size: CGSize(width: 310, height: 28))
        addPlatform(center: CGPoint(x: 1740, y: 235), size: CGSize(width: 260, height: 28))
    }

    private func addPlatform(center: CGPoint, size: CGSize) {
        let rect = CGRect(
            x: center.x - size.width * 0.5,
            y: center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
        platformRects.append(rect)

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

        let face = SKShapeNode(rectOf: CGSize(width: 20, height: 6), cornerRadius: 3)
        face.fillColor = UIColor(red: 0.48, green: 0.82, blue: 1, alpha: 1)
        face.strokeColor = .clear
        face.position = CGPoint(x: 5, y: 10)
        face.name = "face"
        playerVisual.addChild(face)

        let glow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 14))
        glow.fillColor = UIColor(red: 0.35, green: 0.7, blue: 1, alpha: 0.1)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: -35)
        glow.zPosition = -1
        playerVisual.addChild(glow)

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

        jumpLabel.text = "JUMP"
        jumpLabel.fontSize = 15
        jumpLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)
        jumpLabel.verticalAlignmentMode = .center
        jumpLabel.horizontalAlignmentMode = .center

        buildLabel.text = "RESET CONTROLLER V12"
        buildLabel.fontSize = 12
        buildLabel.fontColor = UIColor(white: 1, alpha: 0.86)
        buildLabel.horizontalAlignmentMode = .center
        buildLabel.verticalAlignmentMode = .center

        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel)

        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(jumpButton)
        hud.addChild(buildLabel)

        let labels = [
            debugModeLabel,
            debugYLabel,
            debugVYLabel,
            debugGroundLabel,
            debugCoyoteLabel,
            debugBufferLabel,
            debugCollisionLabel,
            debugTouchLabel
        ]

        for label in labels {
            label.fontSize = 11
            label.fontColor = UIColor(white: 1, alpha: 0.86)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            hud.addChild(label)
        }
    }

    private func configureButton(_ button: SKShapeNode) {
        button.removeAllChildren()
        button.removeAllActions()
        button.setScale(1)
        button.alpha = 1
        button.fillColor = UIColor(white: 0.12, alpha: 0.62)
        button.strokeColor = UIColor(white: 1, alpha: 0.16)
        button.lineWidth = 2
    }

    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }

        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let bottomPadding = max(72, size.height * 0.14)

        leftButton.position = CGPoint(x: -halfW + 82, y: -halfH + bottomPadding)
        rightButton.position = CGPoint(x: -halfW + 182, y: -halfH + bottomPadding)
        jumpButton.position = CGPoint(x: halfW - 92, y: -halfH + bottomPadding + 4)
        buildLabel.position = CGPoint(x: 0, y: halfH - 28)

        let debugX = -halfW + 18
        let debugTopY = halfH - 28
        let labels = [
            debugModeLabel,
            debugYLabel,
            debugVYLabel,
            debugGroundLabel,
            debugCoyoteLabel,
            debugBufferLabel,
            debugCollisionLabel,
            debugTouchLabel
        ]

        for (index, label) in labels.enumerated() {
            label.position = CGPoint(x: debugX, y: debugTopY - CGFloat(index) * 16)
        }
    }

    // MARK: - Touch input in SKView coordinates

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            touchCounter += 1
            let id = ObjectIdentifier(touch)
            let control = classifyControl(at: touch.location(in: skView), in: skView)
            if let control {
                activeControls[id] = control
                if control == .jump {
                    queueJump()
                }
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

            if let newControl {
                activeControls[id] = newControl
                if newControl == .jump && oldControl != .jump {
                    queueJump()
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
            activeControls.removeValue(forKey: ObjectIdentifier(touch))
        }
        recalculateMoveInput()
        refreshButtonVisuals()
    }

    private func classifyControl(at point: CGPoint, in skView: SKView) -> Control? {
        let width = skView.bounds.width
        let height = skView.bounds.height

        // Intentionally generous view-space hit zones for real iPhone testing.
        // Any touch on the right 45% of the physical SKView is jump.
        if point.x >= width * 0.55 {
            return .jump
        }

        // Movement lives in the lower-left half.
        guard point.y >= height * 0.45 else { return nil }
        if point.x < width * 0.24 {
            return .left
        }
        if point.x < width * 0.50 {
            return .right
        }
        return nil
    }

    private func queueJump() {
        jumpCounter += 1
        jumpBufferRemaining = jumpBufferDuration
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
            // Clamp pauses/hitches; substeps handle the remaining movement safely.
            dt = min(max(currentTime - lastUpdateTime, 0), 1.0 / 30.0)
        }
        lastUpdateTime = currentTime

        updateTimers(dt)
        consumeBufferedJumpIfPossible()
        updateHorizontalVelocity(CGFloat(dt))

        velocity.dy = max(maxFallSpeed, velocity.dy + gravity * CGFloat(dt))
        integrateKinematicMotion(CGFloat(dt))

        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
        updateDebugHUD()
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

        velocity.dy = jumpVelocity
        isGrounded = false
        coyoteRemaining = 0
        jumpBufferRemaining = 0
        buildLabel.text = "JUMP OK #\(jumpCounter)"
        playJumpAnimation()
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

        frameCollisionCount = 0
        isGrounded = false

        for _ in 0..<steps {
            moveHorizontally(stepDX)
            moveVertically(stepDY)
        }

        // Hard world bounds are part of the kinematic controller, not SpriteKit physics.
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
            frameCollisionCount += 1
            rect = playerRect
        }
    }

    private func moveVertically(_ amount: CGFloat) {
        // Even when amount is zero we do not need a ground probe: gravity creates a
        // small downward step every grounded frame, which is resolved here.
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
            frameCollisionCount += 1
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

    private func updatePlayerVisuals(_ dt: CGFloat) {
        let speedRatio = min(abs(velocity.dx) / runSpeed, 1)
        let verticalRatio = max(-1, min(1, velocity.dy / jumpVelocity))
        let targetRotation = -facing * speedRatio * 0.055
        playerVisual.zRotation += (targetRotation - playerVisual.zRotation) * min(1, dt * 11)

        var targetScaleX: CGFloat = 1
        var targetScaleY: CGFloat = 1

        if !isGrounded {
            if verticalRatio > 0 {
                targetScaleX = 0.96
                targetScaleY = 1.045
            } else {
                targetScaleX = 1.035
                targetScaleY = 0.97
            }
        } else if speedRatio > 0.08 {
            let wave = sin(CGFloat(lastUpdateTime) * 11) * 0.015 * speedRatio
            targetScaleX += wave
            targetScaleY -= wave
        }

        playerVisual.xScale += (targetScaleX - playerVisual.xScale) * min(1, dt * 12)
        playerVisual.yScale += (targetScaleY - playerVisual.yScale) * min(1, dt * 12)

        if let face = playerVisual.childNode(withName: "face") {
            let targetX = facing * 5
            face.position.x += (targetX - face.position.x) * min(1, dt * 16)
        }
    }

    private func playJumpAnimation() {
        playerVisual.removeAction(forKey: "jump")
        let stretch = SKAction.scaleX(to: 0.93, y: 1.08, duration: 0.06)
        stretch.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.11)
        settle.timingMode = .easeOut
        playerVisual.run(SKAction.sequence([stretch, settle]), withKey: "jump")
    }

    private func refreshButtonVisuals() {
        let leftPressed = activeControls.values.contains(.left)
        let rightPressed = activeControls.values.contains(.right)
        let jumpPressed = activeControls.values.contains(.jump)

        animateButton(leftButton, pressed: leftPressed)
        animateButton(rightButton, pressed: rightPressed)
        animateButton(jumpButton, pressed: jumpPressed)
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

    private func updateDebugHUD() {
        debugModeLabel.text = "MODE: KINEMATIC / NO SKPHYSICS"
        debugYLabel.text = "Y: \(Int(player.position.y.rounded()))"
        debugVYLabel.text = "VY: \(Int(velocity.dy.rounded()))"
        debugGroundLabel.text = "GROUND: \(isGrounded)"
        debugCoyoteLabel.text = String(format: "COYOTE: %.3f", coyoteRemaining)
        debugBufferLabel.text = String(format: "BUFFER: %.3f", jumpBufferRemaining)
        debugCollisionLabel.text = "COLLISIONS: \(frameCollisionCount)"
        debugTouchLabel.text = "TOUCH: \(touchCounter) JUMPS: \(jumpCounter)"
    }

    private func moveToward(_ current: CGFloat, _ target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        if abs(target - current) <= maxDelta {
            return target
        }
        return current + (target > current ? maxDelta : -maxDelta)
    }
}
