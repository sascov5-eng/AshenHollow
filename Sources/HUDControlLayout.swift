import Foundation

enum HUDControlKind: CaseIterable, Equatable {
    case left
    case right
    case up
    case down
    case focus
    case attack
    case jump
}

struct HUDPoint: Equatable {
    let x: Double
    let y: Double
}

struct HUDControlTarget: Equatable {
    let center: HUDPoint
    let visualRadius: Double
    let hitRadius: Double
}

struct HUDControlLayout {
    let viewWidth: Double
    let viewHeight: Double
    let safeBottomInset: Double

    private let dpadCenterX: Double
    private let baselineY: Double
    private let dpadStep: Double = 56

    init(
        viewWidth: Double,
        viewHeight: Double,
        safeBottomInset: Double = 0
    ) {
        self.viewWidth = max(1, viewWidth)
        self.viewHeight = max(1, viewHeight)
        self.safeBottomInset = max(0, safeBottomInset)

        let proposedDPadX = self.viewWidth * 0.20
        self.dpadCenterX = min(145, max(120, proposedDPadX))

        let bottomClearance = max(116, self.safeBottomInset + 95)
        self.baselineY = max(96, self.viewHeight - bottomClearance)
    }

    func target(for kind: HUDControlKind) -> HUDControlTarget {
        switch kind {
        case .left:
            return target(
                x: dpadCenterX - dpadStep,
                y: baselineY,
                visualRadius: 32,
                hitRadius: 42
            )
        case .right:
            return target(
                x: dpadCenterX + dpadStep,
                y: baselineY,
                visualRadius: 32,
                hitRadius: 42
            )
        case .up:
            return target(
                x: dpadCenterX,
                y: baselineY - dpadStep,
                visualRadius: 32,
                hitRadius: 42
            )
        case .down:
            return target(
                x: dpadCenterX,
                y: baselineY + dpadStep,
                visualRadius: 32,
                hitRadius: 42
            )
        case .focus:
            return target(
                x: viewWidth - 300,
                y: baselineY,
                visualRadius: 42,
                hitRadius: 52
            )
        case .attack:
            return target(
                x: viewWidth - 190,
                y: baselineY,
                visualRadius: 47,
                hitRadius: 58
            )
        case .jump:
            return target(
                x: viewWidth - 75,
                y: baselineY,
                visualRadius: 51,
                hitRadius: 62
            )
        }
    }

    func resolve(x: Double, y: Double) -> HUDControlKind? {
        var best: (kind: HUDControlKind, distance: Double)?

        for kind in HUDControlKind.allCases {
            let target = target(for: kind)
            let distance = hypot(x - target.center.x, y - target.center.y)
            guard distance <= target.hitRadius else { continue }

            if best == nil || distance < best!.distance {
                best = (kind, distance)
            }
        }

        return best?.kind
    }

    private func target(
        x: Double,
        y: Double,
        visualRadius: Double,
        hitRadius: Double
    ) -> HUDControlTarget {
        HUDControlTarget(
            center: HUDPoint(x: x, y: y),
            visualRadius: visualRadius,
            hitRadius: hitRadius
        )
    }
}
