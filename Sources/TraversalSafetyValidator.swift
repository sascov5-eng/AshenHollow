import Foundation

enum TraversalTransferResult: Equatable {
    case safe
    case unsafe(String)
}

struct TraversalSafetyValidator {
    let tuning: PlayerMovementTuning

    private let mandatoryRiseLimit = 80.0
    private let mandatoryHorizontalGapLimit = 170.0
    private let minimumMandatoryLandingWidth = 180.0
    private let minimumTutorialLandingWidth = 260.0
    private let dashTeachingGapRange = 230.0...255.0
    private let takeoffEdgeMargin = 20.0
    private let topClearanceMargin = 3.0

    func validateOrdinaryTransfer(
        from source: RoomPlatform,
        to target: RoomPlatform
    ) -> TraversalTransferResult {
        let rise = top(of: target) - top(of: source)
        if rise > mandatoryRiseLimit {
            return .unsafe("vertical rise \(rounded(rise)) exceeds mandatory 80 pt limit")
        }

        if target.size.width < minimumMandatoryLandingWidth {
            return .unsafe("landing width \(rounded(target.size.width)) is below mandatory 180 pt minimum")
        }

        let gap = clearHorizontalGap(from: source, to: target)
        if gap > mandatoryHorizontalGapLimit {
            return .unsafe("horizontal gap \(rounded(gap)) exceeds conservative ordinary-jump envelope")
        }

        if rise > 0, wouldCatchColliderSide(from: source, to: target, requiredRise: rise) {
            return .unsafe("side collision risk: collider reaches platform face before feet clear the landing top")
        }

        return .safe
    }

    func validateDashTeachingTransfer(
        from source: RoomPlatform,
        to target: RoomPlatform
    ) -> TraversalTransferResult {
        if target.size.width < minimumTutorialLandingWidth {
            return .unsafe("landing width \(rounded(target.size.width)) is below Dash tutorial 260 pt minimum")
        }

        let gap = clearHorizontalGap(from: source, to: target)
        if !dashTeachingGapRange.contains(gap) {
            return .unsafe("Dash teaching gap \(rounded(gap)) must stay within 230...255 pt")
        }

        let rise = top(of: target) - top(of: source)
        if rise > 5 {
            return .unsafe("Dash tutorial landing must be equal/lower or within 5 pt of takeoff height")
        }

        let conservativeJumpReach = mandatoryHorizontalGapLimit
        let pureDash = tuning.pureDashDisplacement
        if gap >= conservativeJumpReach + pureDash {
            return .unsafe("Dash teaching gap exceeds conservative jump-plus-Dash reach")
        }

        return .safe
    }

    func validateVerticalStep(
        from source: RoomPlatform,
        to target: RoomPlatform
    ) -> TraversalTransferResult {
        let rise = top(of: target) - top(of: source)
        if rise > mandatoryRiseLimit {
            return .unsafe("vertical step \(rounded(rise)) exceeds mandatory 80 pt limit")
        }
        return validateOrdinaryTransfer(from: source, to: target)
    }

    private func wouldCatchColliderSide(
        from source: RoomPlatform,
        to target: RoomPlatform,
        requiredRise: Double
    ) -> Bool {
        let halfColliderWidth = tuning.colliderWidth * 0.5
        let sourceMinX = minX(source)
        let sourceMaxX = maxX(source)
        let targetMinX = minX(target)
        let targetMaxX = maxX(target)

        let movingRight = target.center.x >= source.center.x
        let takeoffCenterX: Double
        let sideContactCenterX: Double

        if movingRight {
            takeoffCenterX = sourceMaxX - halfColliderWidth - takeoffEdgeMargin
            sideContactCenterX = targetMinX - halfColliderWidth
        } else {
            takeoffCenterX = sourceMinX + halfColliderWidth + takeoffEdgeMargin
            sideContactCenterX = targetMaxX + halfColliderWidth
        }

        let horizontalDistance = abs(sideContactCenterX - takeoffCenterX)
        if horizontalDistance <= 0 {
            return true
        }

        // Use a deliberately conservative first-play horizontal speed rather than
        // theoretical max run speed. The level should still work without a perfect run-up.
        let conservativeHorizontalSpeed = max(1, tuning.runSpeed * 0.825)
        let timeToFace = horizontalDistance / conservativeHorizontalSpeed

        // If the player would not meet the platform until after the full airborne
        // window, this check is irrelevant; horizontal reach rules handle that case.
        let flightTime = 2 * tuning.jumpVelocity / tuning.gravity
        if timeToFace >= flightTime {
            return false
        }

        let verticalDisplacement =
            tuning.jumpVelocity * timeToFace -
            0.5 * tuning.gravity * timeToFace * timeToFace

        return verticalDisplacement < requiredRise + topClearanceMargin
    }

    private func clearHorizontalGap(from source: RoomPlatform, to target: RoomPlatform) -> Double {
        if target.center.x >= source.center.x {
            return max(0, minX(target) - maxX(source))
        }
        return max(0, minX(source) - maxX(target))
    }

    private func minX(_ platform: RoomPlatform) -> Double {
        platform.center.x - platform.size.width * 0.5
    }

    private func maxX(_ platform: RoomPlatform) -> Double {
        platform.center.x + platform.size.width * 0.5
    }

    private func top(of platform: RoomPlatform) -> Double {
        platform.center.y + platform.size.height * 0.5
    }

    private func rounded(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
