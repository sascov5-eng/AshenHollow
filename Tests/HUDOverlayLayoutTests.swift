import Foundation

@inline(__always)
func expectOverlay(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct HUDOverlayLayoutTestsMain {
    static func main() {
        let layout = HUDOverlayLayout(
            viewWidth: 667,
            viewHeight: 375,
            safeTopInset: 0,
            safeLeftInset: 59,
            safeRightInset: 59
        )

        let health = layout.healthCenter
        expectOverlay(health.x >= 59 + 63, "health cluster stays inside the left safe area")
        expectOverlay(health.y >= 50 && health.y <= 70, "health cluster stays near the top edge")

        let roomTitle = layout.roomTitleCenter
        expectOverlay(abs(roomTitle.x - 333.5) < 0.001, "room title stays horizontally centered")
        expectOverlay(roomTitle.y <= 32, "room title stays near the top edge")

        let combatStatus = layout.combatStatusCenter
        expectOverlay(abs(combatStatus.x - roomTitle.x) < 0.001, "combat status aligns with room title")
        expectOverlay(combatStatus.y > roomTitle.y, "combat status sits below the room title")
        expectOverlay(combatStatus.y < 60, "combat status remains in the top HUD band")

        let local = layout.cameraLocalPosition(
            for: health,
            sceneWidth: 844,
            sceneHeight: 390
        )
        let reconstructedScreenX = (local.x + 422) / 844 * 667
        let reconstructedScreenY = (195 - local.y) / 390 * 375
        expectOverlay(abs(reconstructedScreenX - health.x) < 0.001, "camera mapping preserves health screen X across resize")
        expectOverlay(abs(reconstructedScreenY - health.y) < 0.001, "camera mapping preserves health screen Y across resize")

        print("HUDOverlayLayoutTests: PASS")
    }
}
