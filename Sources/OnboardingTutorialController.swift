import Foundation

enum OnboardingStep: Equatable {
    case move
    case jump
    case attack
    case complete
}

enum OnboardingPrompt: Equatable {
    case move
    case jump
    case attack
    case focus
}

struct OnboardingTutorialController {
    private(set) var step: OnboardingStep = .move
    private(set) var focusHintVisible = false

    private var lastPlayerX: Double?
    private var accumulatedHorizontalTravel: Double = 0
    private var tutorialJumpStarted = false
    private var observedMeleeHitSequence: Int = 0
    private var focusHintDismissed = false
    private var leftOnboardingArea = false

    private let movementTravelRequirement: Double = 120

    var primaryPrompt: OnboardingPrompt? {
        guard !leftOnboardingArea else { return nil }
        switch step {
        case .move: return .move
        case .jump: return .jump
        case .attack: return .attack
        case .complete: return nil
        }
    }

    var visiblePrompt: OnboardingPrompt? {
        if let primaryPrompt {
            return primaryPrompt
        }
        if focusHintVisible, !leftOnboardingArea {
            return .focus
        }
        return nil
    }

    mutating func recordPlayerX(_ x: Double) {
        defer { lastPlayerX = x }
        guard !leftOnboardingArea, step == .move else { return }
        guard let previous = lastPlayerX else { return }

        accumulatedHorizontalTravel += abs(x - previous)
        if accumulatedHorizontalTravel >= movementTravelRequirement {
            step = .jump
            tutorialJumpStarted = false
        }
    }

    mutating func recordJumpStarted() {
        guard !leftOnboardingArea, step == .jump else { return }
        tutorialJumpStarted = true
    }

    mutating func recordLanding() {
        guard !leftOnboardingArea,
              step == .jump,
              tutorialJumpStarted else {
            return
        }
        tutorialJumpStarted = false
        step = .attack
    }

    mutating func recordAcceptedMeleeHitSequence(_ sequence: Int) {
        defer { observedMeleeHitSequence = max(observedMeleeHitSequence, sequence) }
        guard !leftOnboardingArea, step == .attack else { return }
        if sequence > observedMeleeHitSequence {
            step = .complete
        }
    }

    mutating func updateFocusEligibility(missingHP: Bool, canAffordFocus: Bool) {
        guard !leftOnboardingArea, !focusHintDismissed else {
            focusHintVisible = false
            return
        }
        focusHintVisible = missingHP && canAffordFocus
    }

    mutating func recordSuccessfulHeal() {
        focusHintVisible = false
        focusHintDismissed = true
    }

    mutating func leaveOnboardingArea() {
        leftOnboardingArea = true
        focusHintVisible = false
        focusHintDismissed = true
    }
}
