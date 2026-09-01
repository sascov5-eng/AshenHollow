from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f"Missing signature for {label}")

# GameScene integration.
path = Path("Sources/GameScene.swift")
text = path.read_text()

text = replace_once(
    text,
    '    private let dashLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")\n',
    '    private let dashLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")\n    private let tutorialLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")\n',
    "tutorial label property",
)

text = replace_once(
    text,
    '''        dashLabel.text = "DASH"
        dashLabel.fontSize = 13
        dashLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)
        dashLabel.verticalAlignmentMode = .center
        dashLabel.horizontalAlignmentMode = .center

        leftButton.addChild(leftArrow)
''',
    '''        dashLabel.text = "DASH"
        dashLabel.fontSize = 13
        dashLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)
        dashLabel.verticalAlignmentMode = .center
        dashLabel.horizontalAlignmentMode = .center

        tutorialLabel.name = "v24OnboardingPrompt"
        tutorialLabel.fontSize = 14
        tutorialLabel.fontColor = UIColor(red: 0.72, green: 0.91, blue: 1.0, alpha: 0.96)
        tutorialLabel.horizontalAlignmentMode = .center
        tutorialLabel.verticalAlignmentMode = .center
        tutorialLabel.zPosition = 1300
        tutorialLabel.isHidden = true

        leftButton.addChild(leftArrow)
''',
    "tutorial label setup",
)

text = replace_once(
    text,
    '''        hud.addChild(attackButton)
        hud.addChild(jumpButton)
        hud.addChild(dashButton)
    }
''',
    '''        hud.addChild(attackButton)
        hud.addChild(jumpButton)
        hud.addChild(dashButton)
        hud.addChild(tutorialLabel)
    }
''',
    "tutorial label HUD attachment",
)

text = replace_once(
    text,
    '''        position(attackButton, as: .attack)
        position(jumpButton, as: .jump)
        position(dashButton, as: .dash)
    }
''',
    '''        position(attackButton, as: .attack)
        position(jumpButton, as: .jump)
        position(dashButton, as: .dash)

        let safeTop = view?.safeAreaInsets.top ?? 0
        tutorialLabel.position = CGPoint(
            x: 0,
            y: halfH - safeTop - 88
        )
    }
''',
    "tutorial label layout",
)

text = replace_once(
    text,
    '''        if context.focus.consumeCompletedHeal() {
            _ = context.vitals.heal(1)
            focusStartDamageSequence = nil
        }
''',
    '''        if context.focus.consumeCompletedHeal() {
            _ = context.vitals.heal(1)
            context.onboarding.recordSuccessfulHeal()
            focusStartDamageSequence = nil
        }
''',
    "successful focus event",
)

text = replace_once(
    text,
    '''        velocity.dy = bufferedJumpWasReleased ? jumpReleaseVelocity : jumpVelocity
        isGrounded = false
        coyoteRemaining = 0
''',
    '''        velocity.dy = bufferedJumpWasReleased ? jumpReleaseVelocity : jumpVelocity
        if let context = V21RuntimeBootstrap.context(from: self),
           context.activeRoomID == .approach {
            context.onboarding.recordJumpStarted()
        }
        isGrounded = false
        coyoteRemaining = 0
''',
    "successful jump event",
)

text = replace_once(
    text,
    '''        resolveAttackHitOnEnemy()
        updateEnemyPresentation(CGFloat(dt))
        updateAnimationState(CGFloat(dt))
''',
    '''        resolveAttackHitOnEnemy()
        updateOnboardingTutorial()
        updateEnemyPresentation(CGFloat(dt))
        updateAnimationState(CGFloat(dt))
''',
    "onboarding frame update",
)

insert_before = '    // MARK: - Presentation\n\n    private func updateCamera(_ dt: CGFloat) {'
new_block = '''    private func updateOnboardingTutorial() {
        guard let context = V21RuntimeBootstrap.context(from: self) else {
            tutorialLabel.isHidden = true
            applyTutorialHighlight(nil)
            return
        }

        guard context.activeRoomID == .approach else {
            tutorialLabel.isHidden = true
            applyTutorialHighlight(nil)
            return
        }

        context.onboarding.recordPlayerX(Double(player.position.x))
        if landedThisFrame {
            context.onboarding.recordLanding()
        }
        context.onboarding.recordAcceptedMeleeHitSequence(
            context.focus.acceptedMeleeHitSequence
        )
        context.onboarding.updateFocusEligibility(
            missingHP: context.vitals.health.hp < context.vitals.health.maxHP,
            canAffordFocus: context.focus.essence >= context.focus.healCost
        )

        guard let prompt = context.onboarding.visiblePrompt else {
            tutorialLabel.isHidden = true
            applyTutorialHighlight(nil)
            return
        }

        tutorialLabel.isHidden = false
        switch prompt {
        case .move:
            tutorialLabel.text = "MOVE   ←   →"
        case .jump:
            tutorialLabel.text = "JUMP"
        case .attack:
            tutorialLabel.text = "ATTACK"
        case .focus:
            tutorialLabel.text = "HOLD FOCUS TO HEAL"
        }
        applyTutorialHighlight(prompt)
    }

    private func applyTutorialHighlight(_ prompt: OnboardingPrompt?) {
        let buttons = [leftButton, rightButton, upButton, downButton, focusButton, attackButton, jumpButton, dashButton]
        for button in buttons {
            button.strokeColor = UIColor(white: 1, alpha: 0.14)
            button.lineWidth = 2
        }

        let highlighted: [SKShapeNode]
        switch prompt {
        case .move:
            highlighted = [leftButton, rightButton]
        case .jump:
            highlighted = [jumpButton]
        case .attack:
            highlighted = [attackButton]
        case .focus:
            highlighted = [focusButton]
        case .none:
            highlighted = []
        }

        for button in highlighted {
            button.strokeColor = UIColor(red: 0.48, green: 0.88, blue: 1.0, alpha: 0.96)
            button.lineWidth = 4
        }
    }

    // MARK: - Presentation

    private func updateCamera(_ dt: CGFloat) {'''
text = replace_once(text, insert_before, new_block, "onboarding presentation helpers")
path.write_text(text)

# Leaving Approach permanently closes onboarding prompts for this runtime.
path = Path("Sources/RoomRuntimeInstaller.swift")
text = path.read_text()
text = replace_once(
    text,
    '''            state.activeRoomID = roomID
            context.activeRoomID = roomID
            context.levelComplete = false
''',
    '''            state.activeRoomID = roomID
            context.activeRoomID = roomID
            if roomID != .approach {
                context.onboarding.leaveOnboardingArea()
            }
            context.levelComplete = false
''',
    "leave onboarding area",
)
path.write_text(text)

print("Integrated contextual onboarding into GameScene and room runtime")
