import Foundation
import CoreGraphics

struct TraversalValidationIssue: Equatable, CustomStringConvertible {
    let traversalID: String
    let message: String
    var description: String { "\(traversalID): \(message)" }
}

enum TraversalReachabilityValidator {
    static func validate(layout: TestLocationSpec, tuning: PlayerMovementTuning) -> [TraversalValidationIssue] {
        var issues: [TraversalValidationIssue] = []
        let gravity = CGFloat(tuning.gravity)
        let jumpV = CGFloat(tuning.jumpVelocity)
        let runSpeed = CGFloat(tuning.runSpeed)
        let dashBonus = CGFloat(tuning.dashSpeed * tuning.dashDuration)
        let maxJumpHeight = jumpV * jumpV / (2 * gravity)
        let fullAirTime = 2 * jumpV / gravity
        let runningRange = runSpeed * fullAirTime

        for t in layout.traversals {
            let dx = abs(t.to.x - t.from.x)
            let dy = t.to.y - t.from.y
            if t.landingWidth < CGFloat(tuning.colliderWidth) * 2.0 {
                issues.append(.init(traversalID: t.id, message: "landing margin too small"))
            }
            if t.headClearance < CGFloat(tuning.colliderHeight) + 20 {
                issues.append(.init(traversalID: t.id, message: "insufficient head clearance"))
            }
            switch t.kind {
            case .walk:
                if dy > 24 { issues.append(.init(traversalID: t.id, message: "walk transition rises too much")) }
            case .ordinaryJump:
                if dy > maxJumpHeight * 0.98 { issues.append(.init(traversalID: t.id, message: "ordinary jump too high")) }
                if dx > runningRange * 0.72 { issues.append(.init(traversalID: t.id, message: "ordinary jump too wide")) }
            case .runningJump:
                if dy > maxJumpHeight * 0.95 { issues.append(.init(traversalID: t.id, message: "running jump too high")) }
                if dx > runningRange * 0.98 { issues.append(.init(traversalID: t.id, message: "running jump too wide")) }
            case .jumpDash:
                if dy > maxJumpHeight * 0.9 { issues.append(.init(traversalID: t.id, message: "jump+dash rise too high")) }
                if dx > runningRange + dashBonus * 1.05 { issues.append(.init(traversalID: t.id, message: "jump+dash gap too wide")) }
            case .wallJump:
                let shaftWidth = abs(t.to.x - t.from.x)
                if shaftWidth > CGFloat(tuning.wallJumpHorizontalSpeed) * 1.5 {
                    issues.append(.init(traversalID: t.id, message: "wall-jump shaft too wide"))
                }
            case .movingPlatformTransfer:
                if dx > runningRange * 0.9 || abs(dy) > maxJumpHeight * 1.15 {
                    issues.append(.init(traversalID: t.id, message: "moving platform transfer unreachable"))
                }
            }
        }

        let playerHalfW = CGFloat(tuning.colliderWidth) * 0.5
        let playerHalfH = CGFloat(tuning.colliderHeight) * 0.5
        for cp in layout.checkpoints {
            let frame = CGRect(x: cp.position.x - playerHalfW, y: cp.position.y - playerHalfH,
                               width: CGFloat(tuning.colliderWidth), height: CGFloat(tuning.colliderHeight))
            if layout.hazards.contains(where: { $0.rect.intersects(frame) }) {
                issues.append(.init(traversalID: cp.id, message: "checkpoint intersects hazard"))
            }
        }

        let tutorialSet = Set(layout.tutorials.map(\.mechanic))
        for missing in TestLocationSpec.requiredTutorialMechanics.subtracting(tutorialSet) {
            issues.append(.init(traversalID: "tutorial", message: "missing \(missing.rawValue)"))
        }

        if layout.checkpoints.count < 4 { issues.append(.init(traversalID: "checkpoints", message: "expected at least four")) }
        if Set(layout.movingPlatforms.map(\.axis)) != Set([.horizontal, .vertical]) {
            issues.append(.init(traversalID: "moving-platforms", message: "horizontal and vertical required"))
        }
        return issues
    }
}
