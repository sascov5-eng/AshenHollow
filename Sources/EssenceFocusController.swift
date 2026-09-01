import Foundation

struct EssenceFocusController {
    let maxEssence: Int
    let essencePerHit: Int
    let healCost: Int
    let focusDuration: TimeInterval

    private(set) var essence: Int = 0
    private(set) var isFocusing: Bool = false
    private(set) var acceptedMeleeHitSequence: Int = 0
    private var focusRemaining: TimeInterval = 0
    private var completedHealPending: Bool = false
    private var completionConfirmationArmed: Bool = false

    var focusProgress: Double {
        guard isFocusing else { return 0 }
        return max(0, min(1, 1 - focusRemaining / focusDuration))
    }

    init(
        maxEssence: Int = 100,
        essencePerHit: Int = 34,
        healCost: Int = 100,
        focusDuration: TimeInterval = 1.0
    ) {
        self.maxEssence = max(1, maxEssence)
        self.essencePerHit = max(1, essencePerHit)
        self.healCost = max(1, healCost)
        self.focusDuration = max(0.01, focusDuration)
    }

    mutating func gainFromAcceptedMeleeHit() {
        acceptedMeleeHitSequence += 1
        essence = min(maxEssence, essence + essencePerHit)
    }

    @discardableResult
    mutating func beginFocus(currentHP: Int, maxHP: Int) -> Bool {
        guard !isFocusing,
              currentHP > 0,
              currentHP < maxHP,
              essence >= healCost else {
            return false
        }

        completedHealPending = false
        completionConfirmationArmed = false
        isFocusing = true
        focusRemaining = focusDuration
        return true
    }

    mutating func updateFocus(dt: TimeInterval) {
        guard isFocusing, dt > 0 else { return }

        focusRemaining = max(0, focusRemaining - dt)
        if focusRemaining == 0 {
            isFocusing = false
            completedHealPending = true
            completionConfirmationArmed = false
        }
    }

    mutating func cancelFocus() {
        isFocusing = false
        focusRemaining = 0
        completedHealPending = false
        completionConfirmationArmed = false
    }

    mutating func consumeCompletedHeal() -> Bool {
        guard completedHealPending else { return false }

        if !completionConfirmationArmed {
            completionConfirmationArmed = true
            return false
        }

        completedHealPending = false
        completionConfirmationArmed = false
        essence = max(0, essence - healCost)
        return true
    }
}
