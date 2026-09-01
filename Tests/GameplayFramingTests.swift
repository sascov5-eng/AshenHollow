import Foundation

@inline(__always)
func expectFraming(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct GameplayFramingTestsMain {
    static func main() {
        let framing = GameplayFraming(
            cameraScale: 1.55,
            playerColliderHeight: 60,
            lowerControlMargin: 18
        )

        // Physical-device class from the reported recording.
        let viewWidth = 910.0
        let viewHeight = 512.0
        let hud = HUDControlLayout(viewWidth: viewWidth, viewHeight: viewHeight)
        let groundPlayerY = 130.0

        let baseY = framing.cameraBaseY(
            sceneHeight: viewHeight,
            playerGroundCenterY: groundPlayerY,
            hudLayout: hud
        )

        let playerBottomFromTop = framing.screenYFromTop(
            worldY: groundPlayerY - 30,
            cameraY: baseY,
            sceneHeight: viewHeight
        )
        let lowerControlTop = framing.primaryLowerControlBandTop(hudLayout: hud)

        expectFraming(
            playerBottomFromTop <= lowerControlTop - 18 + 0.001,
            "grounded player stays above the primary lower HUD control band"
        )
        expectFraming(baseY < viewHeight * 0.5, "camera center shifts downward to frame gameplay higher")
        expectFraming(baseY >= 175 && baseY <= 225, "910x512 framing stays inside a stable camera-Y envelope")

        // Resize-fill must adapt rather than depend on the original 844x390 scene size.
        let compactHUD = HUDControlLayout(viewWidth: 844, viewHeight: 390)
        let compactBaseY = framing.cameraBaseY(
            sceneHeight: 390,
            playerGroundCenterY: groundPlayerY,
            hudLayout: compactHUD
        )
        expectFraming(compactBaseY < 195, "compact landscape framing also raises gameplay above controls")

        print("GameplayFramingTests: PASS")
    }
}
