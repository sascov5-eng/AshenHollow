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

        let dash = layout.target(for: .dash)
        expectHUD(layout.resolve(x: dash.center.x, y: dash.center.y) == .dash, "visible Dash center resolves to Dash")
        expectHUD(dash.center.x - dash.visualRadius >= 0, "Dash stays inside left edge")
        expectHUD(dash.center.x + dash.visualRadius <= width, "Dash stays inside right edge")
        expectHUD(dash.center.y - dash.visualRadius >= 0, "Dash stays inside top edge")
        expectHUD(dash.center.y + dash.visualRadius <= height - safeBottom, "Dash stays above bottom safe area")

        let attack = layout.target(for: .attack)
        let jump = layout.target(for: .jump)
        expectHUD(distance(dash.center, attack.center) > dash.visualRadius + attack.visualRadius, "Dash does not visually overlap Attack")
        expectHUD(distance(dash.center, jump.center) > dash.visualRadius + jump.visualRadius, "Dash does not visually overlap Jump")

        let overlay = HUDOverlayLayout(
            viewWidth: width,
            viewHeight: height,
            safeTopInset: 0,
            safeLeftInset: 59,
            safeRightInset: 59
        )

        let health = overlay.healthCenter
        expectHUD(health.x >= 59 + 63, "health cluster stays inside the left safe area")
        expectHUD(health.y >= 50 && health.y <= 70, "health cluster stays near the top edge")

        let roomTitle = overlay.roomTitleCenter
        expectHUD(abs(roomTitle.x - width * 0.5) < 0.001, "room title stays horizontally centered")
        expectHUD(roomTitle.y <= 32, "room title stays near the top edge")

        let combatStatus = overlay.combatStatusCenter
        expectHUD(abs(combatStatus.x - roomTitle.x) < 0.001, "combat status aligns with room title")
        expectHUD(combatStatus.y > roomTitle.y, "combat status sits below the room title")
        expectHUD(combatStatus.y < 60, "combat status remains in the top HUD band")

        let local = overlay.cameraLocalPosition(
            for: health,
            sceneWidth: 844,
            sceneHeight: 390
        )
        let reconstructedScreenX = (local.x + 422) / 844 * width
        let reconstructedScreenY = (195 - local.y) / 390 * height
        expectHUD(abs(reconstructedScreenX - health.x) < 0.001, "camera mapping preserves health screen X across resize")
        expectHUD(abs(reconstructedScreenY - health.y) < 0.001, "camera mapping preserves health screen Y across resize")

        print("HUDControlLayoutTests: PASS")
    }
}
