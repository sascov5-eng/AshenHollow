from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f"Missing signature: {label}")

# ---------------- GameScene ----------------
path = Path("Sources/GameScene.swift")
text = path.read_text()

text = replace_once(
    text,
    '''        cancelFocus()
        facing = direction > 0 ? 1 : -1
    }
''',
    '''        cancelFocus()
        facing = direction > 0 ? 1 : -1
        context.traversalTeaching.recordDashStarted()
    }
''',
    "record successful Dash teaching event",
)

text = replace_once(
    text,
    '''        dashController.restoreAirDash()
        currentWallClingSide = nil
        return true
    }
''',
    '''        dashController.restoreAirDash()
        currentWallClingSide = nil
        context.traversalTeaching.recordWallJump()
        return true
    }
''',
    "record successful Wall Jump teaching event",
)

old_tutorial = '''    private func updateOnboardingTutorial() {
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
'''

new_tutorial = '''    private func updateOnboardingTutorial() {
        guard let context = V21RuntimeBootstrap.context(from: self) else {
            tutorialLabel.isHidden = true
            applyTutorialHighlight(nil)
            return
        }

        if context.activeRoomID == .approach {
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

            if let prompt = context.onboarding.visiblePrompt {
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
                return
            }
        }

        if let prompt = context.traversalTeaching.prompt {
            tutorialLabel.isHidden = false
            switch prompt {
            case .dash:
                tutorialLabel.text = "DASH"
            case .wallTraversal:
                tutorialLabel.text = "HOLD TOWARD WALL + JUMP"
            }
            applyTraversalTutorialHighlight(prompt)
            return
        }

        tutorialLabel.isHidden = true
        applyTutorialHighlight(nil)
    }
'''
text = replace_once(text, old_tutorial, new_tutorial, "contextual tutorial presentation")

insert_after = '''    private func applyTutorialHighlight(_ prompt: OnboardingPrompt?) {
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
'''

with_traversal_highlight = insert_after + '''
    private func applyTraversalTutorialHighlight(_ prompt: TraversalTeachingPrompt) {
        applyTutorialHighlight(nil)

        let highlighted: [SKShapeNode]
        switch prompt {
        case .dash:
            highlighted = [dashButton]
        case .wallTraversal:
            highlighted = [leftButton, rightButton, jumpButton]
        }

        for button in highlighted {
            button.strokeColor = UIColor(red: 0.48, green: 0.88, blue: 1.0, alpha: 0.96)
            button.lineWidth = 4
        }
    }
'''
text = replace_once(text, insert_after, with_traversal_highlight, "traversal HUD highlighting")
path.write_text(text)

# ---------------- RoomRuntimeInstaller ----------------
path = Path("Sources/RoomRuntimeInstaller.swift")
text = path.read_text()

text = replace_once(
    text,
    '''                label.text = shortcut ? "SHORTCUT" : (room.id == .wardenChamber ? "FINISH" : "EXIT")
''',
    '''                label.text = V24WorldReactionResolver.exitLabel(
                    state: presentation,
                    requiredAbility: exit.requiredAbility,
                    shortcut: shortcut,
                    completionExit: exit.completesLevel
                )
''',
    "open exit label resolver",
)

text = replace_once(
    text,
    '''                label.text = "LOCKED"
''',
    '''                label.text = V24WorldReactionResolver.exitLabel(
                    state: presentation,
                    requiredAbility: exit.requiredAbility,
                    shortcut: shortcut,
                    completionExit: exit.completesLevel
                )
''',
    "combat locked exit label resolver",
)

text = replace_once(
    text,
    '''                label.text = exit.requiredAbility == .wallTraversal ? "WALL" : "ABILITY"
''',
    '''                label.text = V24WorldReactionResolver.exitLabel(
                    state: presentation,
                    requiredAbility: exit.requiredAbility,
                    shortcut: shortcut,
                    completionExit: exit.completesLevel
                )
''',
    "ability locked exit label resolver",
)

old_shrine = '''        func refreshShrinePresentation(_ shrine: SKNode, placement: AbilityShrinePlacement) {
            let consumed = context.progression.state.consumedShrines.contains(placement.id)
            shrine.alpha = consumed ? 0.34 : 1.0
            if let label = shrine.childNode(withName: "shrineLabel") as? SKLabelNode {
                label.text = consumed ? "DORMANT" : shrineTitle(placement.ability)
            }
            if let artifact = shrine.childNode(withName: "artifact") as? SKShapeNode {
                artifact.fillColor = consumed
                    ? UIColor(white: 0.32, alpha: 0.72)
                    : UIColor(red: 0.38, green: 0.84, blue: 1.0, alpha: 0.92)
            }
        }
'''
new_shrine = '''        func refreshShrinePresentation(_ shrine: SKNode, placement: AbilityShrinePlacement) {
            let presentation = V24WorldReactionResolver.shrineState(
                id: placement.id,
                consumedShrines: context.progression.state.consumedShrines
            )
            let consumed = presentation == .dormant
            shrine.alpha = consumed ? 0.34 : 1.0
            if let label = shrine.childNode(withName: "shrineLabel") as? SKLabelNode {
                label.text = consumed ? "DORMANT" : shrineTitle(placement.ability)
            }
            if let artifact = shrine.childNode(withName: "artifact") as? SKShapeNode {
                artifact.fillColor = consumed
                    ? UIColor(white: 0.32, alpha: 0.72)
                    : UIColor(red: 0.38, green: 0.84, blue: 1.0, alpha: 0.92)
            }
        }

        func refreshCheckpointPresentation(_ marker: SKShapeNode, checkpointID: CheckpointID) {
            let presentation = V24WorldReactionResolver.checkpointState(
                id: checkpointID,
                currentCheckpoint: context.progression.state.checkpoint.id
            )
            let active = presentation == .active
            marker.fillColor = active
                ? UIColor(red: 0.30, green: 0.82, blue: 1.0, alpha: 0.28)
                : UIColor(red: 0.26, green: 0.66, blue: 0.92, alpha: 0.14)
            marker.strokeColor = active
                ? UIColor(red: 0.68, green: 0.96, blue: 1.0, alpha: 0.96)
                : UIColor(red: 0.48, green: 0.86, blue: 1.0, alpha: 0.58)
            marker.lineWidth = active ? 4 : 2
            if let label = marker.childNode(withName: "checkpointLabel") as? SKLabelNode {
                label.text = active ? "ACTIVE" : "CHECKPOINT"
                label.fontColor = active
                    ? UIColor(red: 0.74, green: 0.96, blue: 1.0, alpha: 1)
                    : UIColor(white: 0.88, alpha: 0.78)
            }
        }
'''
text = replace_once(text, old_shrine, new_shrine, "shrine and checkpoint resolver presentation")

old_marker = '''            if let trigger = room.checkpointTriggers.first {
                let marker = SKShapeNode(ellipseOf: CGSize(width: 34, height: 72))
                marker.name = "v24CheckpointMarker"
                marker.fillColor = UIColor(red: 0.26, green: 0.66, blue: 0.92, alpha: 0.14)
                marker.strokeColor = UIColor(red: 0.48, green: 0.86, blue: 1.0, alpha: 0.58)
                marker.lineWidth = 2
                marker.position = CGPoint(
                    x: CGFloat(trigger.trigger.x + trigger.trigger.width * 0.5),
                    y: CGFloat(trigger.trigger.y + trigger.trigger.height * 0.5)
                )
                marker.zPosition = 23
                scene.addChild(marker)
            }
'''
new_marker = '''            if let trigger = room.checkpointTriggers.first {
                let marker = SKShapeNode(ellipseOf: CGSize(width: 34, height: 72))
                marker.name = "v24CheckpointMarker"
                marker.position = CGPoint(
                    x: CGFloat(trigger.trigger.x + trigger.trigger.width * 0.5),
                    y: CGFloat(trigger.trigger.y + trigger.trigger.height * 0.5)
                )
                marker.zPosition = 23

                let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
                label.name = "checkpointLabel"
                label.fontSize = 8
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: 0, y: 48)
                marker.addChild(label)

                refreshCheckpointPresentation(marker, checkpointID: trigger.checkpoint.id)
                scene.addChild(marker)
            }
'''
text = replace_once(text, old_marker, new_marker, "checkpoint marker active/inactive presentation")

text = replace_once(
    text,
    '''            ), context.progression.claimShrine(
                placement.id,
                ability: placement.ability,
                checkpoint: placement.checkpoint
            ) {
                if let shrine = scene.childNode(withName: "v24AbilityShrine") {
''',
    '''            ), context.progression.claimShrine(
                placement.id,
                ability: placement.ability,
                checkpoint: placement.checkpoint
            ) {
                context.traversalTeaching.begin(for: placement.ability)
                if let shrine = scene.childNode(withName: "v24AbilityShrine") {
''',
    "start traversal teaching on fresh shrine claim",
)

text = replace_once(
    text,
    '''                context.progression.activateCheckpoint(checkpoint)
            }

            if !context.levelComplete && state.transitionCooldown <= 0 {
''',
    '''                context.progression.activateCheckpoint(checkpoint)
                if let marker = scene.childNode(withName: "v24CheckpointMarker") as? SKShapeNode {
                    refreshCheckpointPresentation(marker, checkpointID: checkpoint.id)
                }
            }

            if let checkpointTrigger = room.checkpointTriggers.first,
               let marker = scene.childNode(withName: "v24CheckpointMarker") as? SKShapeNode {
                refreshCheckpointPresentation(marker, checkpointID: checkpointTrigger.checkpoint.id)
            }

            if !context.levelComplete && state.transitionCooldown <= 0 {
''',
    "refresh checkpoint reaction",
)

path.write_text(text)
print("Integrated V24 world reactions and traversal teaching runtime")
