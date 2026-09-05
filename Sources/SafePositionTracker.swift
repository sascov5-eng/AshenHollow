import Foundation
import CoreGraphics

final class SafePositionTracker {
    private(set) var safePosition: CGPoint?

    func update(candidate: CGPoint, isGrounded: Bool, isSafe: Bool, isDashing: Bool, isWallSliding: Bool, edgeSafe: Bool) {
        guard isGrounded, isSafe, edgeSafe, !isDashing, !isWallSliding else { return }
        safePosition = candidate
    }

    func reset(to position: CGPoint) {
        safePosition = position
    }
}
