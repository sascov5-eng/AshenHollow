import Foundation

@inline(__always)
func expectFullRoute(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct V24FullRouteValidationTestsMain {
    static func main() {
        let level = RoomController.makeV24DemoV2()
        let validator = V24RouteValidator(tuning: .current)
        let report = validator.validate(level: level)

        let mandatoryRooms: [RoomID] = [
            .approach, .lowerHall, .brokenGallery, .dashShrine,
            .furnacePassage, .watcherHall, .hollowShaft,
            .ashenAscent, .wardenGate, .wardenChamber
        ]

        for roomID in mandatoryRooms {
            expectFullRoute(
                report.roomResults[roomID] == .safe,
                "\(roomID) has a safe ordered route from spawn to exit: \(String(describing: report.roomResults[roomID]))"
            )
        }

        let furnaceRoute = V24MandatoryRoute.manifest(for: .furnacePassage)
        expectFullRoute(furnaceRoute != nil, "Furnace Passage has a route manifest")
        expectFullRoute(
            (furnaceRoute?.steps.count ?? 99) <= 6,
            "Furnace Passage no longer uses a long shelf staircase"
        )

        print("V24FullRouteValidationTests: PASS")
    }
}
