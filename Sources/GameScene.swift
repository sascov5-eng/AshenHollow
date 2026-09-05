import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let player = SKShapeNode(rectOf: CGSize(width: 42, height: 64), cornerRadius: 10)
    private let playerVisual = SKNode()
    private let gameCamera = SKCameraNode()
    private let hud = SKNode()

    private var platforms: [SKShapeNode] = []
    private var platformRects: [CGRect] = []
    private var worldWidth: CGFloat = 2200

    private let colliderSize = CGSize(width: 36, height: 60)
    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1900
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2400
    private let gravity: CGFloat = -1700
    private let jumpVelocity: CGFloat = 610
    private let jumpReleaseVelocity: CGFloat = 285
    private let maxFallSpeed: CGFloat = -900
    private let maxMotionPerSubstep: CGFloat = 5

    private var velocity = CGVector.zero
    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1
    private var isGrounded = false

    private let coyoteDuration: TimeInterval = 0.12
    private var coyoteTimer: TimeInterval = 0
    private let jumpBufferDuration: TimeInterval = 0.12
    private var jumpBufferTimer: TimeInterval = 0
    private var jumpHeld = false
    private var lastUpdateTime: TimeInterval = 0

    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 4.2
    private let cameraLookAhead: CGFloat = 120
    private let cameraVerticalOffset: CGFloat = 22

    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let jumpButton = SKShapeNode(circleOfRadius: 51)
    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let jumpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let buildLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var leftTouches = Set<ObjectIdentifier>()
    private var rightTouches = Set<ObjectIdentifier>()
    private var jumpTouches = Set<ObjectIdentifier>()

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        buildWorld()
        buildPlayer()
        buildCamera()
        buildHUD()
        layoutHUD()

        isGrounded = isStandingOnSurface()
        coyoteTimer = isGrounded ? coyoteDuration : 0
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func buildWorld() {
        platforms.removeAll()
        platformRects.removeAll()
        worldWidth = max(2200, size.width * 3.0)

        let backdrop = SKShapeNode(rectOf: CGSize(width: worldWidth, height: max(size.height, 520)))
        backdrop.fillColor = UIColor(red: 0.035, green: 0.042, blue: 0.06, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldWidth * 0.5, y: max(size.height, 520) * 0.5)
        backdrop.zPosition = -100
        addChild(backdrop)

        for index in 0..<12 {
            let pillar = SKShapeNode(
                rectOf: CGSize(
                    width: 62 + CGFloat(index % 3) * 18,
                    height: 170 + CGFloat(index % 4) * 45
                ),
                cornerRadius: 16
            )
            pillar.fillColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 0.72)
            pillar.strokeColor = .clear
            pillar.position = CGPoint(x: 120 + CGFloat(index) * 175, y: 115 + pillar.frame.height * 0.5)
            pillar.zPosition = -50
            addChild(pillar)
        }

        addPlatform(center: CGPoint(x: worldWidth * 0.5, y: 60), size: CGSize(width: worldWidth, height: 80))
        addPlatform(center: CGPoint(x: 520, y: 190), size: CGSize(width: 260, height: 28))
        addPlatform(center: CGPoint(x: 900, y: 255), size: CGSize(width: 230, height: 28))
        addPlatform(center: CGPoint(x: 1320, y: 175), size: CGSize(width: 310, height: 28))
        addPlatform(center: CGPoint(x: 1740, y: 235), size: CGSize(width: 260, height: 28))
    }

    private func addPlatform(center: CGPoint, size: CGSize) {
        let platform = SKShapeNode(rectOf: size, cornerRadius: 7)
        platform.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        platform.strokeColor = UIColor(white: 0.42, alpha: 0.35)
        platform.lineWidth = 2
        platform.position = center
        platform.zPosition = 1
        addChild(platform)
        platforms.append(platform)

        platformRects.append(
            CGRect(
                x: center.x - size.width * 0.5,
                y: center.y - size.height * 0.5,
                width: size.width,
                height: size.height
            )
        )
    }

    private func buildPlayer() {
        player.removeFromParent()
        player.removeAllChildren()
        playerVisual.removeAllChildren()

        player.fillColor = UIColor(red: 0.78, green: 0.82, blue: 0.9, alpha: 1)
        player.strokeColor = UIColor(white: 1, alpha: 0.22)
        player.lineWidth = 2
        player.zPosition = 50
        player.position = CGPoint(x: 230, y: 130)

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
        velocity = .zero
    }

    private func buildCamera() {
        gameCamera.removeFromParent()
        addChild(gameCamera)
        camera = gameCamera
        gameCamera.setScale(cameraZoom)
        let halfVisibleWidth = size.width * 0.5 * cameraZoom
        let startX = max(halfVisibleWidth, player.position.x + 120)
        gameCamera.position = CGPoint(x: startX, y: size.height * 0.5 + cameraVerticalOffset)
    }

    private func buildHUD() {
        hud.removeFromParent()
        hud.removeAllChildren()
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

        buildLabel.text = "KINEMATIC JUMP V5.2"
        buildLabel.fontSize = 12
        buildLabel.fontColor = UIColor(white: 1, alpha: 0.72)
        buildLabel.horizontalAlignmentMode = .center
        buildLabel.verticalAlignmentMode = .center

        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel)
        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(jumpButton)
        hud.addChild(buildLabel)
    }

    private func configureButton(_ button: SKShapeNode) {
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
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)
            if isInside(point, button: leftButton, radius: 60) {
                leftTouches.insert(id)
                animateButton(leftButton, pressed: true)
            } else if isInside(point, button: rightButton, radius: 60) {
                rightTouches.insert(id)
                animateButton(rightButton, pressed: true)
            } else if isInside(point, button: jumpButton, radius: 120) {
                jumpTouches.insert(id)
                jumpHeld = true
                jumpBufferTimer = jumpBufferDuration
                tryConsumeJump()
                animateButton(jumpButton, pressed: true)
            }
        }
        updateInputTarget()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)
            leftTouches.remove(id)
            rightTouches.remove(id)
            if isInside(point, button: leftButton, radius: 60) {
                leftTouches.insert(id)
            } else if isInside(point, button: rightButton, radius: 60) {
                rightTouches.insert(id)
            }
        }
        updateInputTarget()
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
            leftTouches.remove(id)
            rightTouches.remove(id)
            if jumpTouches.remove(id) != nil && jumpTouches.isEmpty {
                jumpHeld = false
                if velocity.dy > jumpReleaseVelocity {
                    velocity.dy = jumpReleaseVelocity
                }
            }
        }
        updateInputTarget()
        refreshButtonVisuals()
    }

    private func isInside(_ point: CGPoint, button: SKShapeNode, radius: CGFloat) -> Bool {
        hypot(point.x - button.position.x, point.y - button.position.y) <= radius
    }

    private func updateInputTarget() {
        targetMoveInput = (leftTouches.isEmpty ? 0 : -1) + (rightTouches.isEmpty ? 0 : 1)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval = lastUpdateTime == 0
            ? 1.0 / 60.0
            : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        updateTimers(dt)
        updateHorizontal(CGFloat(dt))
        tryConsumeJump()
        updateVertical(CGFloat(dt))
        movePlayer(CGFloat(dt))
        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
    }

    private func updateTimers(_ dt: TimeInterval) {
        if isGrounded {
            coyoteTimer = coyoteDuration
        } else {
            coyoteTimer = max(0, coyoteTimer - dt)
        }
        jumpBufferTimer = max(0, jumpBufferTimer - dt)
    }

    private func updateHorizontal(_ dt: CGFloat) {
        let inputResponse: CGFloat = 12
        moveInput += (targetMoveInput - moveInput) * min(1, inputResponse * dt)
        let targetVX = moveInput * runSpeed
        let accelerating = abs(targetMoveInput) > 0.01
        let acceleration = accelerating
            ? (isGrounded ? groundAcceleration : airAcceleration)
            : (isGrounded ? groundDeceleration : airAcceleration * 0.5)

        velocity.dx = moveToward(velocity.dx, targetVX, maxDelta: acceleration * dt)
        if !accelerating && abs(velocity.dx) < 2 {
            velocity.dx = 0
        }
        if abs(targetMoveInput) > 0.01 {
            facing = targetMoveInput > 0 ? 1 : -1
        }
    }

    private func updateVertical(_ dt: CGFloat) {
        velocity.dy = max(maxFallSpeed, velocity.dy + gravity * dt)
        if !jumpHeld && velocity.dy > jumpReleaseVelocity {
            velocity.dy = jumpReleaseVelocity
        }
    }

    private func tryConsumeJump() {
        guard jumpBufferTimer > 0 else { return }
        let canJump = isGrounded || coyoteTimer > 0 || isStandingOnSurface()
        guard canJump else { return }

        velocity.dy = jumpVelocity
        isGrounded = false
        coyoteTimer = 0
        jumpBufferTimer = 0
        playJumpAnimation()
    }

    private func movePlayer(_ dt: CGFloat) {
        let totalDX = velocity.dx * dt
        let totalDY = velocity.dy * dt
        let maxMotion = max(abs(totalDX), abs(totalDY))
        let steps = max(1, Int(ceil(maxMotion / maxMotionPerSubstep)))
        let stepDX = totalDX / CGFloat(steps)
        let stepDY = totalDY / CGFloat(steps)

        var groundedDuringMove = false
        for _ in 0..<steps {
            moveHorizontally(stepDX)
            if moveVertically(stepDY) {
                groundedDuringMove = true
            }
        }

        if groundedDuringMove {
            isGrounded = true
            coyoteTimer = coyoteDuration
        } else {
            isGrounded = isStandingOnSurface()
            if isGrounded {
                coyoteTimer = coyoteDuration
            }
        }
    }

    private func moveHorizontally(_ dx: CGFloat) {
        guard dx != 0 else { return }
        player.position.x += dx
        var frame = playerColliderFrame()

        for rect in platformRects where frame.intersects(rect) {
            if dx > 0 {
                player.position.x = rect.minX - colliderSize.width * 0.5
            } else {
                player.position.x = rect.maxX + colliderSize.width * 0.5
            }
            velocity.dx = 0
            frame = playerColliderFrame()
        }
    }

    @discardableResult
    private func moveVertically(_ dy: CGFloat) -> Bool {
        guard dy != 0 else { return false }
        let oldFrame = playerColliderFrame()
        player.position.y += dy
        var frame = playerColliderFrame()
        var landed = false

        for rect in platformRects where frame.intersects(rect) {
            if dy < 0 && oldFrame.minY >= rect.maxY - 1 {
                player.position.y = rect.maxY + colliderSize.height * 0.5
                velocity.dy = 0
                landed = true
                frame = playerColliderFrame()
            } else if dy > 0 && oldFrame.maxY <= rect.minY + 1 {
                player.position.y = rect.minY - colliderSize.height * 0.5
                velocity.dy = 0
                frame = playerColliderFrame()
            }
        }

        if landed {
            playLandingAnimation()
        }
        return landed
    }

    private func playerColliderFrame(at position: CGPoint? = nil) -> CGRect {
        let p = position ?? player.position
        return CGRect(
            x: p.x - colliderSize.width * 0.5,
            y: p.y - colliderSize.height * 0.5,
            width: colliderSize.width,
            height: colliderSize.height
        )
    }

    private func isStandingOnSurface() -> Bool {
        if velocity.dy > 1 { return false }
        let probePosition = CGPoint(x: player.position.x, y: player.position.y - 2)
        let probe = playerColliderFrame(at: probePosition)
        return platformRects.contains { probe.intersects($0) }
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

    private func playLandingAnimation() {
        playerVisual.removeAction(forKey: "land")
        let squash = SKAction.scaleX(to: 1.06, y: 0.93, duration: 0.05)
        squash.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.10)
        settle.timingMode = .easeOut
        playerVisual.run(SKAction.sequence([squash, settle]), withKey: "land")
    }

    private func updateCamera(_ dt: CGFloat) {
        let visibleHalfWidth = size.width * 0.5 * cameraZoom
        let speedFactor = min(abs(velocity.dx) / runSpeed, 1)
        let direction: CGFloat = abs(velocity.dx) > 6 ? (velocity.dx > 0 ? 1 : -1) : facing
        let lookAhead = direction * cameraLookAhead * speedFactor
        let rawX = player.position.x + lookAhead
        let minX = visibleHalfWidth
        let maxX = max(minX, worldWidth - visibleHalfWidth)
        let targetX = max(minX, min(maxX, rawX))
        let follow = min(1, cameraFollowSpeed * dt)
        gameCamera.position.x += (targetX - gameCamera.position.x) * follow

        let baseY = size.height * 0.5 + cameraVerticalOffset
        let relativeY = player.position.y - 150
        let desiredY = baseY + max(-30, min(55, relativeY * 0.16))
        gameCamera.position.y += (desiredY - gameCamera.position.y) * min(1, 2.4 * dt)
    }

    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: !leftTouches.isEmpty)
        animateButton(rightButton, pressed: !rightTouches.isEmpty)
        animateButton(jumpButton, pressed: !jumpTouches.isEmpty)
    }

    private func animateButton(_ button: SKShapeNode, pressed: Bool) {
        button.removeAction(forKey: "press")
        let scale: CGFloat = pressed ? 0.9 : 1
        let alpha: CGFloat = pressed ? 0.82 : 1
        let action = SKAction.group([
            SKAction.scale(to: scale, duration: 0.08),
            SKAction.fadeAlpha(to: alpha, duration: 0.08)
        ])
        action.timingMode = .easeOut
        button.run(action, withKey: "press")
    }

    private func moveToward(_ current: CGFloat, _ target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        if abs(target - current) <= maxDelta { return target }
        return current + (target > current ? maxDelta : -maxDelta)
    }
}
