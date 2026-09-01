import Foundation

struct DPadAttackDirectionResolver {
    static func resolve(
        upHeld: Bool,
        downHeld: Bool,
        isGrounded: Bool
    ) -> PlayerAttackDirection {
        if upHeld { return .up }
        if downHeld && !isGrounded { return .down }
        return .horizontal
    }
}
