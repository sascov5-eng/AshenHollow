from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()

if "private var dashController = DashController()" in text and "private var wallTraversalController = WallTraversalController()" in text:
    print("V24 traversal integration already present")
    raise SystemExit(0)


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one match, found {count}: {old[:100]!r}")
    text = text.replace(old, new, 1)


replace_once(
    """        case attack\n        case jump\n    }""",
    """        case attack\n        case jump\n        case dash\n    }""",
)

replace_once(
    """    private var smoothedMoveInput: CGFloat = 0\n    private var facing: CGFloat = 1\n\n    // MARK: - Combat""",
    """    private var smoothedMoveInput: CGFloat = 0\n    private var facing: CGFloat = 1\n    private var dashController = DashController()\n    private var wallTraversalController = WallTraversalController()\n    private var currentWallClingSide: WallSide?\n\n    // MARK: - Combat""",
)

replace_once(
    """    private let attackButton = SKShapeNode(circleOfRadius: 47)\n    private let jumpButton = SKShapeNode(circleOfRadius: 51)\n\n    private let leftArrow""",
    """    private let attackButton = SKShapeNode(circleOfRadius: 47)\n    private let jumpButton = SKShapeNode(circleOfRadius: 51)\n    private let dashButton = SKShapeNode(circleOfRadius: 42)\n\n    private let leftArrow""",
)

replace_once(
    """    private let attackLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n    private let jumpLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n\n    // MARK: - Lifecycle""",
    """    private let attackLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n    private let jumpLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n    private let dashLabel = SKLabelNode(fontNamed: \"AvenirNext-Bold\")\n\n    // MARK: - Lifecycle""",
)

replace_once(
    """        animationState = .idle\n        animationStateTime = 0\n        landedThisFrame = false\n    }\n\n    // MARK: - World""",
    """        animationState = .idle\n        animationStateTime = 0\n        landedThisFrame = false\n        dashController = DashController()\n        wallTraversalController = WallTraversalController()\n        currentWallClingSide = nil\n    }\n\n    // MARK: - World""",
)

replace_once(
    """        configureButton(focusButton)\n        configureButton(attackButton)\n        configureButton(jumpButton)\n\n        leftArrow.text""",
    """        configureButton(focusButton)\n        configureButton(attackButton)\n        configureButton(jumpButton)\n        configureButton(dashButton)\n\n        leftArrow.text""",
)

replace_once(
    """        jumpLabel.text = \"JUMP\"\n        jumpLabel.fontSize = 15\n        jumpLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)\n        jumpLabel.verticalAlignmentMode = .center\n        jumpLabel.horizontalAlignmentMode = .center\n\n        leftButton.addChild(leftArrow)""",
    """        jumpLabel.text = \"JUMP\"\n        jumpLabel.fontSize = 15\n        jumpLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)\n        jumpLabel.verticalAlignmentMode = .center\n        jumpLabel.horizontalAlignmentMode = .center\n\n        dashLabel.text = \"DASH\"\n        dashLabel.fontSize = 13\n        dashLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)\n        dashLabel.verticalAlignmentMode = .center\n        dashLabel.horizontalAlignmentMode = .center\n\n        leftButton.addChild(leftArrow)""",
)

replace_once(
    """        focusButton.addChild(focusLabel)\n        attackButton.addChild(attackLabel)\n        jumpButton.addChild(jumpLabel)\n\n        hud.addChild(leftButton)""",
    """        focusButton.addChild(focusLabel)\n        attackButton.addChild(attackLabel)\n        jumpButton.addChild(jumpLabel)\n        dashButton.addChild(dashLabel)\n\n        hud.addChild(leftButton)""",
)

replace_once(
    """        hud.addChild(focusButton)\n        hud.addChild(attackButton)\n        hud.addChild(jumpButton)\n    }""",
    """        hud.addChild(focusButton)\n        hud.addChild(attackButton)\n        hud.addChild(jumpButton)\n        hud.addChild(dashButton)\n    }""",
)

replace_once(
    """        position(focusButton, as: .focus)\n        position(attackButton, as: .attack)\n        position(jumpButton, as: .jump)\n    }""",
    """        position(focusButton, as: .focus)\n        position(attackButton, as: .attack)\n        position(jumpButton, as: .jump)\n        position(dashButton, as: .dash)\n    }""",
)

replace_once(
    """            case .left, .right, .up, .down, .attack, .none:\n                break""",
    """            case .left, .right, .up, .down, .attack, .dash, .none:\n                break""",
)

replace_once(
    """        case .jump:\n            queueJump()\n        case .focus:""",
    """        case .jump:\n            if !tryWallJump() {\n                queueJump()\n            }\n        case .focus:""",
)

replace_once(
    """            tryAttack(direction: direction)\n        case .left, .right, .up, .down:\n            break""",
    """            tryAttack(direction: direction)\n        case .dash:\n            tryDash()\n        case .left, .right, .up, .down:\n            break""",
)

replace_once(
    """        case .attack: return .attack\n        case .jump: return .jump\n        }""",
    """        case .attack: return .attack\n        case .jump: return .jump\n        case .dash: return .dash\n        }""",
)

replace_once(
    """    private func cancelFocus() {\n        guard let context = V21RuntimeBootstrap.context(from: self) else { return }\n        context.focus.cancelFocus()\n        focusStartDamageSequence = nil\n    }\n\n    private func queueJump()""",
    """    private func cancelFocus() {\n        guard let context = V21RuntimeBootstrap.context(from: self) else { return }\n        context.focus.cancelFocus()\n        focusStartDamageSequence = nil\n    }\n\n    private func tryDash() {\n        guard let context = V21RuntimeBootstrap.context(from: self),\n              let direction = dashController.tryStart(\n                  unlocked: context.progression.state.has(.dash),\n                  isGrounded: isGrounded,\n                  inputX: Double(moveInput),\n                  facing: Double(facing)\n              ) else { return }\n\n        cancelFocus()\n        facing = direction > 0 ? 1 : -1\n    }\n\n    private func tryWallJump() -> Bool {\n        guard let context = V21RuntimeBootstrap.context(from: self),\n              context.progression.state.has(.wallTraversal) else {\n            return false\n        }\n\n        let detectedSide = detectedWallContact()\n        let side = currentWallClingSide ?? wallTraversalController.clingSide(\n            unlocked: true,\n            isGrounded: isGrounded,\n            heldDirectionX: Double(moveInput),\n            contactSide: detectedSide\n        )\n        guard let side else { return false }\n\n        cancelFocus()\n        let impulse = wallTraversalController.wallJump(from: side)\n        velocity.dx = CGFloat(impulse.velocityX)\n        velocity.dy = CGFloat(impulse.velocityY)\n        isGrounded = false\n        coyoteRemaining = 0\n        jumpBufferRemaining = 0\n        bufferedJumpWasReleased = false\n        dashController.restoreAirDash()\n        currentWallClingSide = nil\n        return true\n    }\n\n    private func queueJump()""",
)

replace_once(
    """        attackController.update(dt)\n        updateFocusState(dt)\n        updateTimers(dt)""",
    """        attackController.update(dt)\n        dashController.update(dt: dt)\n        wallTraversalController.update(dt: dt)\n        updateFocusState(dt)\n        updateTimers(dt)""",
)

replace_once(
    """        updateHorizontalVelocity(CGFloat(dt))\n        applyPendingCombatImpulses()\n\n        velocity.dy = max(maxFallSpeed, velocity.dy + gravity * CGFloat(dt))\n        integrateKinematicMotion(CGFloat(dt))""",
    """        updateHorizontalVelocity(CGFloat(dt))\n        applyPendingCombatImpulses()\n\n        if !dashController.isDashing {\n            velocity.dy = max(maxFallSpeed, velocity.dy + gravity * CGFloat(dt))\n        }\n        updateWallTraversalState()\n        integrateKinematicMotion(CGFloat(dt))\n\n        if landedThisFrame {\n            dashController.restoreAirDash()\n            currentWallClingSide = nil\n        }""",
)

replace_once(
    """    private func applyPendingCombatImpulses() {\n        guard !pendingCombatImpulses.isEmpty else { return }\n\n        for impulse in pendingCombatImpulses {""",
    """    private func applyPendingCombatImpulses() {\n        guard !pendingCombatImpulses.isEmpty else { return }\n\n        dashController.cancelActiveDash()\n        for impulse in pendingCombatImpulses {\n            if impulse.kind == .pogo {\n                dashController.restoreAirDash()\n            }""",
)

replace_once(
    """    private func updateHorizontalVelocity(_ dt: CGFloat) {\n        let focusing = V21RuntimeBootstrap.context(from: self)?.focus.isFocusing == true""",
    """    private func updateHorizontalVelocity(_ dt: CGFloat) {\n        if dashController.isDashing {\n            velocity.dx = CGFloat(dashController.direction) * 720\n            velocity.dy = 0\n            return\n        }\n\n        let focusing = V21RuntimeBootstrap.context(from: self)?.focus.isFocusing == true""",
)

replace_once(
    """        if player.position.x < halfW {\n            player.position.x = halfW\n            velocity.dx = max(0, velocity.dx)\n        }\n        if player.position.x > worldWidth - halfW {\n            player.position.x = worldWidth - halfW\n            velocity.dx = min(0, velocity.dx)\n        }""",
    """        if player.position.x < halfW {\n            player.position.x = halfW\n            velocity.dx = max(0, velocity.dx)\n            dashController.cancelActiveDash()\n        }\n        if player.position.x > worldWidth - halfW {\n            player.position.x = worldWidth - halfW\n            velocity.dx = min(0, velocity.dx)\n            dashController.cancelActiveDash()\n        }""",
)

replace_once(
    """            }\n            velocity.dx = 0\n            rect = playerRect\n        }\n    }\n\n    private func moveVertically""",
    """            }\n            velocity.dx = 0\n            dashController.cancelActiveDash()\n            rect = playerRect\n        }\n    }\n\n    private func moveVertically""",
)

replace_once(
    """    private func moveVertically(_ amount: CGFloat) {\n        guard amount != 0 else { return }\n\n        player.position.y += amount\n        var rect = playerRect\n        let halfH = colliderSize.height * 0.5\n\n        for platform in platformRects where rect.intersects(platform) {\n            if amount < 0 {\n                player.position.y = platform.maxY + halfH\n                velocity.dy = 0\n                isGrounded = true\n            } else {\n                player.position.y = platform.minY - halfH\n                velocity.dy = 0\n            }\n            rect = playerRect\n        }\n    }\n\n    // MARK: - Presentation""",
    """    private func moveVertically(_ amount: CGFloat) {\n        guard amount != 0 else { return }\n\n        player.position.y += amount\n        var rect = playerRect\n        let halfH = colliderSize.height * 0.5\n\n        for platform in platformRects where rect.intersects(platform) {\n            if amount < 0 {\n                player.position.y = platform.maxY + halfH\n                velocity.dy = 0\n                isGrounded = true\n            } else {\n                player.position.y = platform.minY - halfH\n                velocity.dy = 0\n            }\n            rect = playerRect\n        }\n    }\n\n    private func detectedWallContact() -> WallSide? {\n        let probe: CGFloat = 1\n        let verticalInset: CGFloat = 2\n        let base = playerRect.insetBy(dx: 0, dy: verticalInset)\n        let leftProbe = base.offsetBy(dx: -probe, dy: 0)\n        let rightProbe = base.offsetBy(dx: probe, dy: 0)\n\n        let left = platformRects.contains { leftProbe.intersects($0) && !base.intersects($0) }\n        let right = platformRects.contains { rightProbe.intersects($0) && !base.intersects($0) }\n        if left { return .left }\n        if right { return .right }\n        return nil\n    }\n\n    private func updateWallTraversalState() {\n        guard let context = V21RuntimeBootstrap.context(from: self) else {\n            currentWallClingSide = nil\n            return\n        }\n\n        let side = wallTraversalController.clingSide(\n            unlocked: context.progression.state.has(.wallTraversal),\n            isGrounded: isGrounded,\n            heldDirectionX: Double(moveInput),\n            contactSide: detectedWallContact()\n        )\n\n        if let side {\n            if currentWallClingSide != side {\n                dashController.restoreAirDash()\n            }\n            velocity.dy = max(velocity.dy, CGFloat(wallTraversalController.slideSpeed))\n        }\n        currentWallClingSide = side\n    }\n\n    // MARK: - Presentation""",
)

replace_once(
    """        animateButton(focusButton, pressed: activeControls.values.contains(.focus))\n        animateButton(attackButton, pressed: activeControls.values.contains(.attack))\n        animateButton(jumpButton, pressed: activeControls.values.contains(.jump))\n    }""",
    """        animateButton(focusButton, pressed: activeControls.values.contains(.focus))\n        animateButton(attackButton, pressed: activeControls.values.contains(.attack))\n        animateButton(jumpButton, pressed: activeControls.values.contains(.jump))\n        animateButton(dashButton, pressed: activeControls.values.contains(.dash))\n    }""",
)

path.write_text(text)
print("Applied V24 Dash + Wall Traversal integration to GameScene.swift")
