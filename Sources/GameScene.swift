import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let tuning = PlayerMovementTuning.current

    private let player = SKShapeNode(rectOf: CGSize(width: 42, height: 64), cornerRadius: 10)
    private let playerVisual = SKNode()
    private var playerSprite: SKSpriteNode?
    private var playerFrames: [SKTexture] = []
    private var walkFrameIndex = 0
    private var walkFrameTimer: CGFloat = 0

    private let gameCamera = SKCameraNode()
    private let hud = SKNode()
    private var platformRects: [CGRect] = []
    private var worldWidth: CGFloat = 2200

    private var velocity = CGVector.zero
    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1
    private var isGrounded = false
    private var jumpHeld = false
    private var coyoteTimer: TimeInterval = 0
    private var jumpBufferTimer: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    private var dashController = DashController()
    private var wallController = WallTraversalController()
    private var attackController = AttackController()
    private var essenceController = EssenceFocusController()
    private var currentHP = 5
    private let maxHP = 5
    private var currentWallCling: WallSide?

    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 4.2
    private let cameraLookAhead: CGFloat = 120
    private let cameraVerticalOffset: CGFloat = 22

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
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var leftTouches = Set<ObjectIdentifier>()
    private var rightTouches = Set<ObjectIdentifier>()
    private var jumpTouches = Set<ObjectIdentifier>()

    private var colliderSize: CGSize {
        CGSize(width: CGFloat(tuning.colliderWidth), height: CGFloat(tuning.colliderHeight))
    }

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
        coyoteTimer = isGrounded ? tuning.coyoteDuration : 0
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func buildWorld() {
        platformRects.removeAll()
        worldWidth = max(2200, size.width * 3)

        let backdrop = SKShapeNode(rectOf: CGSize(width: worldWidth, height: max(size.height, 520)))
        backdrop.fillColor = UIColor(red: 0.035, green: 0.042, blue: 0.06, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: worldWidth * 0.5, y: max(size.height, 520) * 0.5)
        backdrop.zPosition = -100
        addChild(backdrop)

        for index in 0..<12 {
            let pillar = SKShapeNode(rectOf: CGSize(width: 62 + CGFloat(index % 3) * 18, height: 170 + CGFloat(index % 4) * 45), cornerRadius: 16)
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
        addPlatform(center: CGPoint(x: 1120, y: 210), size: CGSize(width: 42, height: 220))
        addPlatform(center: CGPoint(x: 1510, y: 230), size: CGSize(width: 42, height: 260))
    }

    private func addPlatform(center: CGPoint, size: CGSize) {
        let node = SKShapeNode(rectOf: size, cornerRadius: 7)
        node.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        node.strokeColor = UIColor(white: 0.42, alpha: 0.35)
        node.lineWidth = 2
        node.position = center
        node.zPosition = 1
        addChild(node)
        platformRects.append(CGRect(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5, width: size.width, height: size.height))
    }

    private func buildPlayer() {
        player.removeFromParent()
        player.removeAllChildren()
        playerVisual.removeAllChildren()
        playerSprite = nil
        playerFrames.removeAll()
        walkFrameIndex = 0
        walkFrameTimer = 0

        player.fillColor = .clear
        player.strokeColor = .clear
        player.zPosition = 50
        player.position = CGPoint(x: 230, y: 130)

        let imageURL = Bundle.main.bundleURL.appendingPathComponent("player_run.png")
        if let data = try? Data(contentsOf: imageURL), let image = UIImage(data: data), let cgImage = image.cgImage {
            let sheet = SKTexture(cgImage: cgImage)
            sheet.filteringMode = .linear
            playerFrames = makePlayerFrames(from: sheet)
            if let first = playerFrames.first {
                let sprite = SKSpriteNode(texture: first)
                sprite.size = CGSize(width: 92, height: 92)
                sprite.position = CGPoint(x: 0, y: 10)
                sprite.zPosition = 10
                playerVisual.addChild(sprite)
                playerSprite = sprite
            }
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

    private func makePlayerFrames(from sheet: SKTexture) -> [SKTexture] {
        var frames: [SKTexture] = []
        for row in 0..<2 {
            for column in 0..<4 {
                let rect = CGRect(x: CGFloat(column) * 0.25, y: row == 0 ? 0.5 : 0, width: 0.25, height: 0.5)
                let texture = SKTexture(rect: rect, in: sheet)
                texture.filteringMode = .linear
                frames.append(texture)
            }
        }
        return frames
    }

    private func buildCamera() {
        gameCamera.removeFromParent()
        addChild(gameCamera)
        camera = gameCamera
        gameCamera.setScale(cameraZoom)
        let halfVisibleWidth = size.width * 0.5 * cameraZoom
        gameCamera.position = CGPoint(x: max(halfVisibleWidth, player.position.x + 120), y: size.height * 0.5 + cameraVerticalOffset)
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

        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel)
        attackButton.addChild(attackLabel)
        dashButton.addChild(dashLabel)
        healButton.addChild(healLabel)
        [leftButton, rightButton, jumpButton, attackButton, dashButton, healButton, statusLabel].forEach { hud.addChild($0) }
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
            } else if isInside(point, button: jumpButton, radius: 110) {
                jumpTouches.insert(id)
                jumpHeld = true
                jumpBufferTimer = tuning.jumpBufferDuration
                tryConsumeJump()
                animateButton(jumpButton, pressed: true)
            } else if isInside(point, button: attackButton, radius: 58) {
                startAttack()
                pulse(attackButton)
            } else if isInside(point, button: dashButton, radius: 58) {
                startDash()
                pulse(dashButton)
            } else if isInside(point, button: healButton, radius: 54) {
                startHeal()
                pulse(healButton)
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
            if isInside(point, button: leftButton, radius: 60) { leftTouches.insert(id) }
            else if isInside(point, button: rightButton, radius: 60) { rightTouches.insert(id) }
        }
        updateInputTarget()
        refreshButtonVisuals()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { releaseTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { releaseTouches(touches) }

    private func releaseTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            leftTouches.remove(id)
            rightTouches.remove(id)
            if jumpTouches.remove(id) != nil && jumpTouches.isEmpty {
                jumpHeld = false
                if velocity.dy > CGFloat(tuning.jumpReleaseVelocity) { velocity.dy = CGFloat(tuning.jumpReleaseVelocity) }
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
        let dt = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        updateTimers(dt)
        updateWallState()
        updateHorizontal(CGFloat(dt))
        tryConsumeJump()
        updateVertical(CGFloat(dt))
        movePlayer(CGFloat(dt))
        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
        updateHUDStatus()
    }

    private func updateTimers(_ dt: TimeInterval) {
        if isGrounded {
            coyoteTimer = tuning.coyoteDuration
            dashController.restoreAirDash()
        } else {
            coyoteTimer = max(0, coyoteTimer - dt)
        }
        jumpBufferTimer = max(0, jumpBufferTimer - dt)
        dashController.update(dt: dt)
        wallController.update(dt: dt)
        attackController.update(dt)
        essenceController.updateFocus(dt: dt)
        if essenceController.consumeCompletedHeal() { currentHP = min(maxHP, currentHP + 1) }
    }

    private func updateWallState() {
        currentWallCling = wallController.clingSide(
            unlocked: true,
            isGrounded: isGrounded,
            heldDirectionX: Double(targetMoveInput),
            contactSide: wallContactSide()
        )
    }

    private func updateHorizontal(_ dt: CGFloat) {
        if dashController.isDashing {
            velocity.dx = CGFloat(dashController.direction * tuning.dashSpeed)
            return
        }

        let inputResponse: CGFloat = 12
        moveInput += (targetMoveInput - moveInput) * min(1, inputResponse * dt)
        let targetVX = moveInput * CGFloat(tuning.runSpeed)
        let accelerating = abs(targetMoveInput) > 0.01
        let acceleration = accelerating
            ? CGFloat(isGrounded ? tuning.groundAcceleration : tuning.airAcceleration)
            : CGFloat(isGrounded ? tuning.groundDeceleration : tuning.airAcceleration * 0.5)
        velocity.dx = moveToward(velocity.dx, targetVX, maxDelta: acceleration * dt)
        if !accelerating && abs(velocity.dx) < 2 { velocity.dx = 0 }
        if abs(targetMoveInput) > 0.01 { facing = targetMoveInput > 0 ? 1 : -1 }
    }

    private func updateVertical(_ dt: CGFloat) {
        if dashController.isDashing {
            velocity.dy = 0
            return
        }
        velocity.dy = max(-CGFloat(tuning.maxFallSpeed), velocity.dy - CGFloat(tuning.gravity) * dt)
        if currentWallCling != nil && velocity.dy < CGFloat(tuning.wallSlideSpeed) {
            velocity.dy = CGFloat(tuning.wallSlideSpeed)
        }
        if !jumpHeld && velocity.dy > CGFloat(tuning.jumpReleaseVelocity) {
            velocity.dy = CGFloat(tuning.jumpReleaseVelocity)
        }
    }

    private func tryConsumeJump() {
        guard jumpBufferTimer > 0 else { return }

        if let side = currentWallCling {
            let impulse = wallController.wallJump(from: side)
            velocity.dx = CGFloat(impulse.velocityX)
            velocity.dy = CGFloat(impulse.velocityY)
            facing = velocity.dx >= 0 ? 1 : -1
            isGrounded = false
            currentWallCling = nil
            jumpBufferTimer = 0
            coyoteTimer = 0
            dashController.restoreAirDash()
            playJumpAnimation()
            return
        }

        let canJump = isGrounded || coyoteTimer > 0 || isStandingOnSurface()
        guard canJump else { return }
        velocity.dy = CGFloat(tuning.jumpVelocity)
        isGrounded = false
        coyoteTimer = 0
        jumpBufferTimer = 0
        playJumpAnimation()
    }

    private func startDash() {
        if let direction = dashController.tryStart(unlocked: true, isGrounded: isGrounded, inputX: Double(targetMoveInput), facing: Double(facing)) {
            essenceController.cancelFocus()
            facing = direction >= 0 ? 1 : -1
            velocity.dx = CGFloat(direction * tuning.dashSpeed)
            velocity.dy = 0
            let squash = SKAction.scaleX(to: 1.18, y: 0.84, duration: 0.05)
            let settle = SKAction.scale(to: 1, duration: 0.12)
            playerVisual.run(SKAction.sequence([squash, settle]), withKey: "dash")
        }
    }

    private func startAttack() {
        essenceController.cancelFocus()
        guard attackController.tryStart(direction: .horizontal) else { return }
        let slash = SKShapeNode()
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 46, startAngle: -0.65, endAngle: 0.65, clockwise: false)
        slash.path = path
        slash.strokeColor = UIColor(white: 1, alpha: 0.95)
        slash.lineWidth = 7
        slash.glowWidth = 5
        slash.zPosition = 80
        slash.position = CGPoint(x: player.position.x + facing * 36, y: player.position.y + 3)
        slash.xScale = facing
        addChild(slash)
        slash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.16), .removeFromParent()]))
        playerVisual.run(SKAction.sequence([
            SKAction.rotate(toAngle: -facing * 0.16, duration: 0.05, shortestUnitArc: true),
            SKAction.rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true)
        ]), withKey: "attack")
    }

    private func startHeal() {
        guard essenceController.beginFocus(currentHP: currentHP, maxHP: maxHP) else { return }
        velocity.dx = 0
        let glow = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.45, duration: 0.15),
            SKAction.fadeAlpha(to: 1, duration: 0.15)
        ])
        playerVisual.run(SKAction.repeat(glow, count: 3), withKey: "heal")
    }

    private func movePlayer(_ dt: CGFloat) {
        let totalDX = velocity.dx * dt
        let totalDY = velocity.dy * dt
        let maxMotion = max(abs(totalDX), abs(totalDY))
        let steps = max(1, Int(ceil(maxMotion / CGFloat(tuning.maxMotionPerSubstep))))
        let stepDX = totalDX / CGFloat(steps)
        let stepDY = totalDY / CGFloat(steps)

        var groundedDuringMove = false
        for _ in 0..<steps {
            moveHorizontally(stepDX)
            if moveVertically(stepDY) { groundedDuringMove = true }
        }

        if groundedDuringMove || isStandingOnSurface() {
            isGrounded = true
            coyoteTimer = tuning.coyoteDuration
            dashController.restoreAirDash()
        } else {
            isGrounded = false
        }
    }

    private func moveHorizontally(_ dx: CGFloat) {
        guard dx != 0 else { return }
        player.position.x += dx
        var frame = playerColliderFrame()
        for rect in platformRects where frame.intersects(rect) {
            if dx > 0 { player.position.x = rect.minX - colliderSize.width * 0.5 }
            else { player.position.x = rect.maxX + colliderSize.width * 0.5 }
            velocity.dx = 0
            dashController.cancelActiveDash()
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

        if landed { playLandingAnimation() }
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
        let frame = playerColliderFrame()
        let inset: CGFloat = 7
        let leftProbe = CGRect(x: frame.minX - 3, y: frame.minY + inset, width: 4, height: max(1, frame.height - inset * 2))
        let rightProbe = CGRect(x: frame.maxX - 1, y: frame.minY + inset, width: 4, height: max(1, frame.height - inset * 2))
        if platformRects.contains(where: { leftProbe.intersects($0) }) { return .left }
        if platformRects.contains(where: { rightProbe.intersects($0) }) { return .right }
        return nil
    }

    private func updatePlayerVisuals(_ dt: CGFloat) {
        let speedRatio = min(abs(velocity.dx) / CGFloat(tuning.runSpeed), 1)
        if currentWallCling != nil {
            playerVisual.zRotation += ((facing * 0.08) - playerVisual.zRotation) * min(1, dt * 12)
        } else {
            let targetRotation = -facing * speedRatio * 0.055
            playerVisual.zRotation += (targetRotation - playerVisual.zRotation) * min(1, dt * 11)
        }

        if let sprite = playerSprite {
            sprite.xScale = facing >= 0 ? 1 : -1
            if isGrounded && abs(velocity.dx) > 20 && !playerFrames.isEmpty {
                walkFrameTimer += dt
                if walkFrameTimer >= 0.085 {
                    walkFrameTimer = 0
                    walkFrameIndex = (walkFrameIndex + 1) % playerFrames.count
                    sprite.texture = playerFrames[walkFrameIndex]
                }
            } else if !playerFrames.isEmpty {
                walkFrameTimer = 0
                walkFrameIndex = 0
                sprite.texture = playerFrames[0]
            }
        }
    }

    private func playJumpAnimation() {
        let stretch = SKAction.scaleX(to: 0.93, y: 1.08, duration: 0.06)
        let settle = SKAction.scale(to: 1, duration: 0.11)
        playerVisual.run(SKAction.sequence([stretch, settle]), withKey: "jump")
    }

    private func playLandingAnimation() {
        let squash = SKAction.scaleX(to: 1.06, y: 0.93, duration: 0.05)
        let settle = SKAction.scale(to: 1, duration: 0.10)
        playerVisual.run(SKAction.sequence([squash, settle]), withKey: "land")
    }

    private func updateCamera(_ dt: CGFloat) {
        let visibleHalfWidth = size.width * 0.5 * cameraZoom
        let speedFactor = min(abs(velocity.dx) / CGFloat(tuning.runSpeed), 1)
        let direction: CGFloat = abs(velocity.dx) > 6 ? (velocity.dx > 0 ? 1 : -1) : facing
        let rawX = player.position.x + direction * cameraLookAhead * speedFactor
        let minX = visibleHalfWidth
        let maxX = max(minX, worldWidth - visibleHalfWidth)
        let targetX = max(minX, min(maxX, rawX))
        gameCamera.position.x += (targetX - gameCamera.position.x) * min(1, cameraFollowSpeed * dt)

        let baseY = size.height * 0.5 + cameraVerticalOffset
        let desiredY = baseY + max(-30, min(55, (player.position.y - 150) * 0.16))
        gameCamera.position.y += (desiredY - gameCamera.position.y) * min(1, 2.4 * dt)
    }

    private func updateHUDStatus() {
        let wallText = currentWallCling == nil ? "" : " • WALL"
        let dashText = dashController.isDashing ? " • DASH" : ""
        statusLabel.text = "HP \(currentHP)/\(maxHP) • LIGHT \(essenceController.essence)/\(essenceController.maxEssence)\(wallText)\(dashText)"
        healButton.alpha = essenceController.essence >= essenceController.healCost && currentHP < maxHP ? 1 : 0.45
        dashButton.alpha = dashController.cooldownRemaining <= 0 ? 1 : 0.5
    }

    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: !leftTouches.isEmpty)
        animateButton(rightButton, pressed: !rightTouches.isEmpty)
        animateButton(jumpButton, pressed: !jumpTouches.isEmpty)
    }

    private func animateButton(_ button: SKShapeNode, pressed: Bool) {
        button.removeAction(forKey: "press")
        let action = SKAction.group([
            SKAction.scale(to: pressed ? 0.9 : 1, duration: 0.08),
            SKAction.fadeAlpha(to: pressed ? 0.82 : 1, duration: 0.08)
        ])
        action.timingMode = .easeOut
        button.run(action, withKey: "press")
    }

    private func pulse(_ button: SKShapeNode) {
        button.run(SKAction.sequence([
            SKAction.scale(to: 0.86, duration: 0.04),
            SKAction.scale(to: 1, duration: 0.09)
        ]), withKey: "tap")
    }

    private func moveToward(_ current: CGFloat, _ target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        if abs(target - current) <= maxDelta { return target }
        return current + (target > current ? maxDelta : -maxDelta)
    }
}
