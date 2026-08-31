import Foundation

struct AttackGestureResolver {
    static let defaultThreshold: Double = 28

    static func resolve(
        deltaX: Double,
        deltaY: Double,
        isGrounded: Bool,
        threshold: Double = defaultThreshold
    ) -> PlayerAttackDirection {
        let safeThreshold = max(1, threshold)

        if abs(deltaY) < safeThreshold {
            return .horizontal
        }

        if deltaY <= -safeThreshold {
            return .up
        }

        if deltaY >= safeThreshold, !isGrounded {
            return .down
        }

        return .horizontal
    }
}
