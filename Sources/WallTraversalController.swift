import Foundation

enum WallSide: Equatable {
    case left
    case right
}

struct WallJumpImpulse: Equatable {
    let velocityX: Double
    let velocityY: Double
}

struct WallTraversalController {
    private let tuning = PlayerMovementTuning.current

    var slideSpeed: Double { tuning.wallSlideSpeed }
    var jumpHorizontalSpeed: Double { tuning.wallJumpHorizontalSpeed }
    var jumpVerticalSpeed: Double { tuning.wallJumpVerticalSpeed }
    var sameWallLockDuration: TimeInterval { tuning.sameWallLockDuration }

    private(set) var lockedWall: WallSide?
    private var lockRemaining: TimeInterval = 0

    mutating func update(dt: TimeInterval) {
        guard dt > 0 else { return }
        lockRemaining = max(0, lockRemaining - dt)
        if lockRemaining == 0 { lockedWall = nil }
    }

    func clingSide(unlocked: Bool, isGrounded: Bool, heldDirectionX: Double, contactSide: WallSide?) -> WallSide? {
        guard unlocked, !isGrounded, let contactSide else { return nil }
        if lockedWall == contactSide && lockRemaining > 0 { return nil }
        switch contactSide {
        case .left where heldDirectionX < 0: return .left
        case .right where heldDirectionX > 0: return .right
        default: return nil
        }
    }

    mutating func wallJump(from side: WallSide) -> WallJumpImpulse {
        lockedWall = side
        lockRemaining = sameWallLockDuration
        return WallJumpImpulse(
            velocityX: side == .left ? jumpHorizontalSpeed : -jumpHorizontalSpeed,
            velocityY: jumpVerticalSpeed
        )
    }
}
