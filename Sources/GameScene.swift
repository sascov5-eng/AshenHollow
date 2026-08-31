import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let world: UInt32 = 1 << 1
    }

    private enum JumpDiagnosticPhase: String {
        case idle = "IDLE"
        case breakContact = "BREAK"
        case impulse = "IMPULSE"
        case restore = "RESTORE"
    }

    private let player = SKShapeNode(rectOf: CGSize(width: 42, height: 64), cornerRadius: 10)
    private let playerVisual = SKNode()
    private let gameCamera = SKCameraNode()
    private let hud = SKNode()

    private var worldWidth: CGFloat = 2200

    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1900
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2400
    private let jumpVelocity: CGFloat = 610
    private let maxFallSpeed: CGFloat = -900
    private let contactBreakNudge: CGFloat = 4

    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1
    private var isGrounded = false
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

    private let debugYLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugVYLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugMaskLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugGravityLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugPhaseLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugTouchLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugRightLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugSetVYLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private var leftTouches = Set<ObjectIdentifier>()
    private var rightTouches = Set<ObjectIdentifier>()
    private var diagnosticRightTouches = Set<ObjectIdentifier>()

    private var touchCounter = 0
    private var rightTouchCounter = 0
    private var lastSetVY: CGFloat = 0
    private var lastYBeforeJump: CGFloat = 0
    private var jumpPhase: JumpDiagnosticPhase = .idle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        physicsWorld.gravity = CGVector(dx: 0, dy: -1700)

        buildWorld()
        buildPlayer()
        buildCamera()
        buildHUD()
        layoutHUD()
        updateGroundedState()
        updateDebugHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func buildWorld() {
        worldWidth = max(2200, size.width * 3.0)

        let backdropHeight = max(size.height, 520)
        let backdrop = SKShapeNode(rectOf: CGSize(width: worldWidth, height: backdropHeight))
        backdrop.fillColor = UIColor(red: 0.035, green: 0.042, blue: 0.06, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldWidth * 0.5, y: backdropHeight * 0.5)
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
            pillar.position = CGPoint(
                x: 120 + CGFloat(index) * 175,
                y: 115 + pillar.frame.height * 0.5
            )
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

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.world
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = 0
        platform.physicsBody = body
        addChild(platform)
    }

    private func buildPlayer() {
        player.removeFromParent()
        player.removeAllChildren()
        playerVisual.removeAllChildren()

        player.fillColor = UIColor(red: 0.78, green: 0.82, blue: 0.9, alpha: 1)
        player.strokeColor = UIColor(white: 1, alpha: 0.22)
        player.lineWidth = 2
        player.zPosition = 50
        player.position = CGPoint(x: 230, y: 136)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: 60))
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.angularDamping = 0
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.world
        body.contactTestBitMask = 0
        body.usesPreciseCollisionDetection = true
        player.physicsBody = body

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

        buildLabel.text = "DIAG JUMP V10"
        buildLabel.fontSize = 12
        buildLabel.fontColor = UIColor(white: 1, alpha: 0.82)
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
            debugYLabel, debugVYLabel, debugMaskLabel, debugGravityLabel,
            debugPhaseLabel, debugTouchLabel, debugRightLabel, debugSetVYLabel
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

        let debugX = -halfW + 22
        let debugTopY = halfH - 28
        let labels = [
            debugYLabel, debugVYLabel, debugMaskLabel, debugGravityLabel,
            debugPhaseLabel, debugTouchLabel, debugRightLabel, debugSetVYLabel
        ]
        for (index, label) in labels.enumerated() {
            label.position = CGPoint(x: debugX, y: debugTopY - CGFloat(index) * 16)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let skView = view else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            touchCounter += 1

            let viewPoint = touch.location(in: skView)
            if viewPoint.x >= skView.bounds.midX {
                rightTouchCounter += 1
                diagnosticRightTouches.insert(id)
                beginTwoPhaseDiagnosticJump()
                continue
            }

            let hudPoint = touch.location(in: hud)
            if isInside(hudPoint, button: leftButton, radius: 60) {
                leftTouches.insert(id)
                animateButton(leftButton, pressed: true)
            } else if isInside(hudPoint, button: rightButton, radius: 60) {
                rightTouches.insert(id)
                animateButton(rightButton, pressed: true)
            }
        }

        updateInputTarget()
        updateDebugHUD()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)

            if diagnosticRightTouches.contains(id) {
                continue
            }

            let hudPoint = touch.location(in: hud)
            leftTouches.remove(id)
            rightTouches.remove(id)

            if isInside(hudPoint, button: leftButton, radius: 60) {
                leftTouches.insert(id)
            } else if isInside(hudPoint, button: rightButton, radius: 60) {
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

    private func beginTwoPhaseDiagnosticJump() {
        guard let body = player.physicsBody else {
            buildLabel.text = "RIGHT TOUCH = NO BODY"
            return
        }

        lastYBeforeJump = player.position.y
        lastSetVY = 0

        // Phase 1: completely clear the existing floor contact for one physics step.
        body.collisionBitMask = 0
        body.affectedByGravity = false
        body.isResting = false
        body.velocity = CGVector(dx: body.velocity.dx, dy: 0)
        player.position.y += contactBreakNudge

        isGrounded = false
        jumpPhase = .breakContact
        buildLabel.text = "V10 BREAK CONTACT"
        updateDebugHUD()
    }

    private func advanceDiagnosticJumpAfterPhysics() {
        guard let body = player.physicsBody else { return }

        switch jumpPhase {
        case .idle:
            updateGroundedState()

        case .breakContact:
            // The old collision manifold has now had one simulation step with MASK=0.
            // Keep collisions disabled for the impulse frame, restore gravity, then launch.
            body.isResting = false
            body.affectedByGravity = true
            lastSetVY = jumpVelocity
            body.velocity = CGVector(dx: body.velocity.dx, dy: jumpVelocity)
            jumpPhase = .impulse
            buildLabel.text = "V10 IMPULSE"
            playJumpAnimation()

        case .impulse:
            // One full physics step has now occurred with no world collision and DY=610.
            // Restore normal world collisions only after the body had a chance to separate.
            body.collisionBitMask = PhysicsCategory.world
            jumpPhase = .restore
            buildLabel.text = "V10 RESTORE MASK"

        case .restore:
            jumpPhase = .idle
            updateGroundedState()
            buildLabel.text = "V10 NORMAL"
        }
    }

    private func releaseTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            diagnosticRightTouches.remove(id)
            leftTouches.remove(id)
            rightTouches.remove(id)
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

        updateHorizontal(CGFloat(dt))
        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
        updateDebugHUD()
    }

    override func didSimulatePhysics() {
        advanceDiagnosticJumpAfterPhysics()
        updateDebugHUD()
    }

    private func updateHorizontal(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let inputResponse: CGFloat = 12
        moveInput += (targetMoveInput - moveInput) * min(1, inputResponse * dt)

        let targetVX = moveInput * runSpeed
        let accelerating = abs(targetMoveInput) > 0.01
        let acceleration = accelerating
            ? (isGrounded ? groundAcceleration : airAcceleration)
            : (isGrounded ? groundDeceleration : airAcceleration * 0.5)

        var vx = moveToward(body.velocity.dx, targetVX, maxDelta: acceleration * dt)
        if !accelerating && abs(vx) < 2 {
            vx = 0
        }

        let vy = max(body.velocity.dy, maxFallSpeed)
        body.velocity = CGVector(dx: vx, dy: vy)

        if abs(targetMoveInput) > 0.01 {
            facing = targetMoveInput > 0 ? 1 : -1
        }
    }

    private func isStandingOnSurface() -> Bool {
        guard let body = player.physicsBody else { return false }
        if body.velocity.dy > 45 { return false }

        let halfWidth: CGFloat = 15
        let halfHeight: CGFloat = 30
        let feetY = player.position.y - halfHeight
        let probe = CGRect(
            x: player.position.x - halfWidth,
            y: feetY - 9,
            width: halfWidth * 2,
            height: 14
        )

        var foundWorld = false
        physicsWorld.enumerateBodies(in: probe) { physicsBody, stop in
            if physicsBody.categoryBitMask & PhysicsCategory.world != 0 {
                foundWorld = true
                stop.pointee = true
            }
        }
        return foundWorld
    }

    private func updateGroundedState() {
        let grounded = isStandingOnSurface()
        if grounded && !isGrounded {
            isGrounded = true
            playLandingAnimation()
        } else {
            isGrounded = grounded
        }
    }

    private func updateDebugHUD() {
        guard let body = player.physicsBody else {
            debugYLabel.text = "Y: NO BODY"
            debugVYLabel.text = "LIVEVY: NO BODY"
            debugMaskLabel.text = "MASK: n/a"
            debugGravityLabel.text = "GRAV: n/a"
            debugPhaseLabel.text = "PHASE: \(jumpPhase.rawValue)"
            debugTouchLabel.text = "TOUCH: \(touchCounter)"
            debugRightLabel.text = "RIGHT: \(rightTouchCounter)"
            debugSetVYLabel.text = "SETVY: \(Int(lastSetVY.rounded()))"
            return
        }

        debugYLabel.text = "Y: \(Int(player.position.y.rounded())) FROM:\(Int(lastYBeforeJump.rounded()))"
        debugVYLabel.text = "LIVEVY: \(Int(body.velocity.dy.rounded()))"
        debugMaskLabel.text = "MASK: \(body.collisionBitMask)"
        debugGravityLabel.text = "GRAV: \(body.affectedByGravity)"
        debugPhaseLabel.text = "PHASE: \(jumpPhase.rawValue)"
        debugTouchLabel.text = "TOUCH: \(touchCounter)"
        debugRightLabel.text = "RIGHT: \(rightTouchCounter)"
        debugSetVYLabel.text = "SETVY: \(Int(lastSetVY.rounded()))"
    }

    private func updatePlayerVisuals(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let speedRatio = min(abs(body.velocity.dx) / runSpeed, 1)
        let verticalRatio = max(-1, min(1, body.velocity.dy / jumpVelocity))
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
        guard let body = player.physicsBody else { return }

        let visibleHalfWidth = size.width * 0.5 * cameraZoom
        let speedFactor = min(abs(body.velocity.dx) / runSpeed, 1)
        let direction: CGFloat = abs(body.velocity.dx) > 6
            ? (body.velocity.dx > 0 ? 1 : -1)
            : facing
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
        animateButton(jumpButton, pressed: !diagnosticRightTouches.isEmpty)
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
        if abs(target - current) <= maxDelta {
            return target
        }
        return current + (target > current ? maxDelta : -maxDelta)
    }
}
