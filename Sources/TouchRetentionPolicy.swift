import Foundation

struct TouchRetentionPolicy {
    static func shouldRetain(
        distanceFromCenter: Double,
        baseRadius: Double,
        toleranceMultiplier: Double = 1.45
    ) -> Bool {
        guard baseRadius > 0, toleranceMultiplier > 0 else { return false }
        return distanceFromCenter <= baseRadius * toleranceMultiplier
    }
}
