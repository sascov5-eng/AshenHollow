import Foundation

@inline(__always)
func expectEncounterSafety(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct V24EncounterSafetyValidatorTestsMain {
    static func main() {
        let level = RoomController.makeV24DemoV2()
        let report = V24EncounterSafetyValidator(tuning: .current).validate(level: level)

        let rooms: [RoomID] = [
            .approach, .lowerHall, .brokenGallery, .dashShrine,
            .furnacePassage, .watcherHall, .hollowShaft,
            .ashenAscent, .wardenGate, .wardenChamber
        ]

        for roomID in rooms {
            expectEncounterSafety(
                report.roomResults[roomID] == .safe,
                "\(roomID) encounter placement is safe: \(String(describing: report.roomResults[roomID]))"
            )
        }

        expectEncounterSafety(level.room(.dashShrine)!.enemySpawns.isEmpty, "Dash Shrine is combat-free")
        expectEncounterSafety(level.room(.hollowShaft)!.enemySpawns.isEmpty, "Hollow Shaft is combat-free")

        print("V24EncounterSafetyValidatorTests: PASS")
    }
}
