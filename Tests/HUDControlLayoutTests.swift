import Foundation

@inline(__always)
func expectHUD(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func distance(_ a: HUDPoint, _ b: HUDPoint) -> Double {
    hypot(a.x - b.x, a.y - b.y)
}

@main
struct HUDControlLayoutTestsMain {
    static func main() {
        let width = 667.0
        let height = 375.0
        let safeBottom = 21.0
        let layout = HUDControlLayout(
            viewWidth: width,
            viewHeight: height,
            safeBottomInset: safeBottom
        )

        let dpadKinds: [HUDControlKind] = [.left, .right, .up, .down]
        for kind in dpadKinds {
            let target = layout.target(for: kind)
            expectHUD(target.center.x - target.visualRadius >= 0, "\(kind) stays inside left edge")
            expectHUD(target.center.x + target.visualRadius <= width, "\(kind) stays inside right edge")
            expectHUD(target.center.y - target.visualRadius >= 0, "\(kind) stays inside top edge")
            expectHUD(
                target.center.y + target.visualRadius <= height - safeBottom,
                "\(kind) stays above bottom safe area"
            )
        }

        for firstIndex in 0..<dpadKinds.count {
            for secondIndex in (firstIndex + 1)..<dpadKinds.count {
                let first = layout.target(for: dpadKinds[firstIndex])
                let second = layout.target(for: dpadKinds[secondIndex])
                expectHUD(
                    distance(first.center, second.center) > first.visualRadius + second.visualRadius,
                    "D-pad visual circles do not overlap"
                )
            }
        }

        for kind in HUDControlKind.allCases {
            let target = layout.target(for: kind)
            expectHUD(
                layout.resolve(x: target.center.x, y: target.center.y) == kind,
                "visible \(kind) center resolves to the same control"
            )
        }

        let focus = layout.target(for: .focus)
        expectHUD(
            layout.resolve(x: focus.center.x + focus.hitRadius * 0.80, y: focus.center.y) == .focus,
            "focus has a usable touch radius around its visible center"
        )

        print("HUDControlLayoutTests: PASS")
    }
}
