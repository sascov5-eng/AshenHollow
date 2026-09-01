import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ApproachAtmosphereLayoutTests {
    static func main() {
        let layout = ApproachAtmosphereLayout.make(roomWidth: 1200, roomHeight: 560)

        expect(layout.roomWidth == 1200, "room width should be preserved")
        expect(layout.roomHeight == 560, "room height should be preserved")
        expect(layout.farStructures.count >= 6, "first room needs a readable far silhouette")
        expect(layout.midStructures.count >= 7, "first room needs layered ruins in midground")
        expect(layout.foregroundDebris.count >= 8, "first room needs foreground breakup without collision")
        expect(layout.fogBands.count >= 3, "first room needs multiple haze depths")
        expect(layout.ashSeeds.count >= 28, "first room needs visible drifting ash")

        expect(layout.startShelter.centerX < 220, "spawn must remain visually sheltered")
        expect(layout.jumpBeacon.centerX > 330 && layout.jumpBeacon.centerX < 570,
               "jump teaching light should frame the existing tutorial block")
        expect(layout.enemyPool.centerX > 680 && layout.enemyPool.centerX < 860,
               "first combat pool should frame the existing Grunt")
        expect(layout.dropShaft.centerX > 1000, "right edge should read as a downward shaft")

        expect(layout.farParallax > 0 && layout.farParallax < layout.midParallax,
               "far layer must move slower than mid layer")
        expect(layout.midParallax < layout.hazeParallax && layout.hazeParallax < 1,
               "haze should sit between world motion and midground motion")

        print("ApproachAtmosphereLayoutTests passed")
    }
}
