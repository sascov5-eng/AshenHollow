import Foundation

@inline(__always)
func expectOnboarding(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct OnboardingTutorialControllerTestsMain {
    static func main() {
        var tutorial = OnboardingTutorialController()

        expectOnboarding(tutorial.step == .move, "tutorial starts with movement")
        expectOnboarding(tutorial.primaryPrompt == .move, "movement prompt is visible first")

        tutorial.recordPlayerX(120)
        tutorial.recordPlayerX(165)
        expectOnboarding(tutorial.step == .move, "45 pt movement is not enough to finish MOVE")
        tutorial.recordPlayerX(245)
        expectOnboarding(tutorial.step == .jump, "125 pt accumulated travel advances to JUMP")
        expectOnboarding(tutorial.primaryPrompt == .jump, "JUMP prompt follows movement")

        tutorial.recordLanding()
        expectOnboarding(tutorial.step == .jump, "landing without a tutorial jump does not advance")
        tutorial.recordJumpStarted()
        expectOnboarding(tutorial.step == .jump, "jump start alone does not count as successful tutorial jump")
        tutorial.recordLanding()
        expectOnboarding(tutorial.step == .attack, "landing after tutorial jump advances to ATTACK")

        tutorial.recordAcceptedMeleeHitSequence(0)
        expectOnboarding(tutorial.step == .attack, "no accepted hit keeps ATTACK active")
        tutorial.recordAcceptedMeleeHitSequence(1)
        expectOnboarding(tutorial.step == .complete, "accepted melee hit completes required onboarding")
        expectOnboarding(tutorial.primaryPrompt == nil, "primary tutorial no longer blocks after ATTACK")

        tutorial.updateFocusEligibility(missingHP: true, canAffordFocus: false)
        expectOnboarding(!tutorial.focusHintVisible, "FOCUS stays hidden without enough Essence")
        tutorial.updateFocusEligibility(missingHP: false, canAffordFocus: true)
        expectOnboarding(!tutorial.focusHintVisible, "FOCUS stays hidden at full HP")
        tutorial.updateFocusEligibility(missingHP: true, canAffordFocus: true)
        expectOnboarding(tutorial.focusHintVisible, "FOCUS appears only when healing is actually possible")
        expectOnboarding(tutorial.visiblePrompt == .focus, "FOCUS becomes visible after required onboarding is complete")

        tutorial.recordSuccessfulHeal()
        expectOnboarding(!tutorial.focusHintVisible, "successful heal dismisses FOCUS tutorial")
        tutorial.updateFocusEligibility(missingHP: true, canAffordFocus: true)
        expectOnboarding(!tutorial.focusHintVisible, "FOCUS tutorial does not repeat after successful heal")

        var noDamageRun = OnboardingTutorialController()
        noDamageRun.recordPlayerX(0)
        noDamageRun.recordPlayerX(140)
        noDamageRun.recordJumpStarted()
        noDamageRun.recordLanding()
        noDamageRun.recordAcceptedMeleeHitSequence(1)
        noDamageRun.leaveOnboardingArea()
        noDamageRun.updateFocusEligibility(missingHP: true, canAffordFocus: true)
        expectOnboarding(!noDamageRun.focusHintVisible, "FOCUS is permanently skipped when player leaves Approach without needing it")
        expectOnboarding(noDamageRun.visiblePrompt == nil, "no tutorial prompt remains after leaving Approach")

        // Same runtime controller survives a death/respawn reset because the scene does not recreate it.
        // Recording another player position must not restart required steps after completion.
        tutorial.recordPlayerX(100)
        expectOnboarding(tutorial.step == .complete, "ordinary respawn cannot restart MOVE/JUMP/ATTACK")

        print("OnboardingTutorialControllerTests: PASS")
    }
}
