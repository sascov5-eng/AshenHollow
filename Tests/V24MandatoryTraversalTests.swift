import Foundation

@inline(__always)
func expectV24Traversal(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func minX(_ p: RoomPlatform) -> Double { p.center.x - p.size.width * 0.5 }
private func maxX(_ p: RoomPlatform) -> Double { p.center.x + p.size.width * 0.5 }
private func top(_ p: RoomPlatform) -> Double { p.center.y + p.size.height * 0.5 }
private func bottom(_ p: RoomPlatform) -> Double { p.center.y - p.size.height * 0.5 }

private func safe(_ result: TraversalTransferResult) -> Bool {
    if case .safe = result { return true }
    return false
}

@main
struct V24MandatoryTraversalTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()
        let validator = TraversalSafetyValidator(tuning: .current)

        let approach = level.room(.approach)!
        let lower = level.room(.lowerHall)!
        let gallery = level.room(.brokenGallery)!
        let dash = level.room(.dashShrine)!
        let furnace = level.room(.furnacePassage)!
        let watcher = level.room(.watcherHall)!
        let shaft = level.room(.hollowShaft)!
        let ascent = level.room(.ashenAscent)!
        let gate = level.room(.wardenGate)!
        let chamber = level.room(.wardenChamber)!

        // Spatial map remains coherent: DOWN / LEFT / DOWN / LEFT / UP / LEFT / UP / LEFT / DOWN.
        expectV24Traversal(approach.worldOrigin.x == lower.worldOrigin.x && approach.worldOrigin.y > lower.worldOrigin.y, "Approach is physically above Lower Hall")
        expectV24Traversal(lower.worldOrigin.y == gallery.worldOrigin.y && lower.worldOrigin.x > gallery.worldOrigin.x, "Broken Gallery is physically left of Lower Hall")
        expectV24Traversal(gallery.worldOrigin.x == dash.worldOrigin.x && gallery.worldOrigin.y > dash.worldOrigin.y, "Dash Shrine is physically below Broken Gallery")
        expectV24Traversal(dash.worldOrigin.y == furnace.worldOrigin.y && dash.worldOrigin.x > furnace.worldOrigin.x, "Furnace Passage is physically left of Dash Shrine")
        expectV24Traversal(furnace.worldOrigin.x == watcher.worldOrigin.x && furnace.worldOrigin.y < watcher.worldOrigin.y, "Watcher Hall is physically above Furnace Passage")
        expectV24Traversal(watcher.worldOrigin.y == shaft.worldOrigin.y && watcher.worldOrigin.x > shaft.worldOrigin.x, "Hollow Shaft is physically left of Watcher Hall")
        expectV24Traversal(shaft.worldOrigin.x == ascent.worldOrigin.x && shaft.worldOrigin.y < ascent.worldOrigin.y, "Ashen Ascent is physically above Hollow Shaft")
        expectV24Traversal(ascent.worldOrigin.y == gate.worldOrigin.y && ascent.worldOrigin.x > gate.worldOrigin.x, "Warden Gate is physically left of Ashen Ascent")
        expectV24Traversal(gate.worldOrigin.x == chamber.worldOrigin.x && gate.worldOrigin.y > chamber.worldOrigin.y, "Warden Chamber is physically below Warden Gate")

        // Approach: solid broad tutorial terrace, not a thin catch shelf.
        let tutorialTerraces = approach.platforms.filter {
            $0.size.width >= 280 && $0.size.height >= 50 && $0.size.height <= 80 && top($0) >= 160 && top($0) <= 180
        }
        expectV24Traversal(tutorialTerraces.count == 1, "Approach has one broad solid onboarding jump terrace")
        if let floor = approach.platforms.first, let terrace = tutorialTerraces.first {
            expectV24Traversal(safe(validator.validateVerticalStep(from: floor, to: terrace)), "Approach onboarding jump stays inside the safe first-play envelope")
        }

        // Lower Hall is a three-terrace descent rather than a jump staircase.
        expectV24Traversal(lower.platforms.count == 3, "Lower Hall uses exactly three broad descending terraces")
        expectV24Traversal(lower.platforms.allSatisfy { $0.size.width >= 360 }, "Lower Hall terraces remain broad combat surfaces")

        // Broken Gallery exposes the later shortcut without making it part of first-pass traversal.
        expectV24Traversal(
            gallery.exits.contains(where: { $0.requiredAbility == .wallTraversal && $0.destinationRoomID == .ashenAscent }),
            "Broken Gallery preserves the Wall Traversal shortcut payoff"
        )

        // Dash Shrine V2: two equal-height floor banks, one 230–255 pt gap, no post-Dash ladder.
        let dashBanks = dash.platforms
            .filter { abs($0.center.y - 60) < 0.001 && abs($0.size.height - 80) < 0.001 }
            .sorted { $0.center.x < $1.center.x }
        expectV24Traversal(dashBanks.count == 2, "Dash Shrine has exactly two main Dash banks")
        if dashBanks.count == 2 {
            let landing = dashBanks[0]
            let source = dashBanks[1]
            let gap = minX(source) - maxX(landing)
            expectV24Traversal(gap >= 230 && gap <= 255, "first Dash gap stays in the 230–255 pt teaching envelope")
            expectV24Traversal(landing.size.width >= 320, "first Dash landing is at least 320 pt wide")
            expectV24Traversal(source.size.width >= 320, "first Dash takeoff bank is broad")
            expectV24Traversal(safe(validator.validateDashTeachingTransfer(from: source, to: landing)), "first Dash transfer passes side-collision and reach validation")
        }
        expectV24Traversal(
            dash.platforms.contains(where: { top($0) < 60 && $0.size.width >= 180 }),
            "Dash Shrine has a low recovery surface below the teaching gap"
        )
        expectV24Traversal(
            dash.platforms.filter { $0.size.height <= 30 && top($0) > 100 }.isEmpty,
            "Dash Shrine has no post-Dash precision shelf ladder"
        )

        // Furnace: one Dash gap plus two broad terraces; old eight-shelf zigzag must never return.
        expectV24Traversal(furnace.platforms.count == 4, "Furnace Passage uses four route surfaces total")
        expectV24Traversal(furnace.platforms.allSatisfy { $0.size.width >= 280 }, "Furnace Passage mandatory surfaces are broad")
        let furnaceBanks = furnace.platforms.filter { abs($0.center.y - 60) < 0.001 && abs($0.size.height - 80) < 0.001 }.sorted { $0.center.x < $1.center.x }
        expectV24Traversal(furnaceBanks.count == 2, "Furnace Passage starts with two broad Dash banks")
        if furnaceBanks.count == 2 {
            let gap = minX(furnaceBanks[1]) - maxX(furnaceBanks[0])
            expectV24Traversal(gap >= 180 && gap <= 255, "Furnace application gap stays inside the Dash envelope")
        }
        expectV24Traversal(
            furnace.platforms.filter { $0.center.y > 60 }.count == 2,
            "Furnace Passage climb uses only two large terraces"
        )

        // Watcher Hall keeps an uninterrupted ground combat route and deliberate cover/firing position.
        expectV24Traversal(watcher.platforms.contains(where: { $0.size.width >= 1100 && $0.size.height >= 70 }), "Watcher Hall has a broad uninterrupted combat floor")
        expectV24Traversal(watcher.enemySpawns.contains(where: { $0.archetype == .ranged }), "Watcher Hall keeps ranged pressure")

        // Hollow Shaft: shrine is walk-accessible before unlock, then one forgiving wall pair and a broad recovery.
        expectV24Traversal(shaft.shrine?.ability == .wallTraversal, "Hollow Shaft still grants Wall Traversal")
        expectV24Traversal((shaft.shrine?.position.y ?? .infinity) <= 140, "Wall shrine remains walk-accessible on the lower floor")
        let walls = shaft.platforms
            .filter { $0.size.width <= 50 && $0.size.height >= 300 }
            .sorted { $0.center.x < $1.center.x }
        expectV24Traversal(walls.count == 2, "Hollow Shaft uses one clean opposing wall pair")
        if walls.count == 2 {
            let innerGap = minX(walls[1]) - maxX(walls[0])
            expectV24Traversal(innerGap >= 170 && innerGap <= 200, "Hollow Shaft inner wall gap is 170–200 pt")
            expectV24Traversal(walls.allSatisfy { bottom($0) >= 145 }, "climb walls start above the walk-accessible shrine floor")
        }
        expectV24Traversal(shaft.enemySpawns.isEmpty, "Hollow Shaft remains enemy-free")
        expectV24Traversal(
            shaft.platforms.contains(where: { $0.size.width >= 300 && top($0) >= 510 }),
            "Hollow Shaft ends on a broad upper recovery ledge"
        )

        // Ashen Ascent: three traversal beats separated by broad recovery surfaces.
        let recoveryPlatforms = ascent.platforms.filter { $0.size.width >= 280 && $0.size.height >= 40 }
        expectV24Traversal(recoveryPlatforms.count >= 4, "Ashen Ascent contains broad start/recovery surfaces between traversal beats")
        let ascentWalls = ascent.platforms.filter { $0.size.width <= 50 && $0.size.height >= 120 }
        expectV24Traversal(ascentWalls.count == 4, "Ashen Ascent contains two deliberate opposing wall pairs")
        let sortedAscentWalls = ascentWalls.sorted { $0.center.x < $1.center.x }
        expectV24Traversal(
            sortedAscentWalls.contains { left in
                sortedAscentWalls.contains { right in
                    right.center.x > left.center.x && (minX(right) - maxX(left)) >= 170 && (minX(right) - maxX(left)) <= 200
                }
            },
            "Ashen Ascent has at least one 170–200 pt wall-jump gap"
        )

        // Warden Gate is a broad final combat space; elevated platform is optional only.
        expectV24Traversal(gate.platforms.first?.size.width ?? 0 >= 1000, "Warden Gate has a broad final combat floor")
        expectV24Traversal(gate.enemySpawns.contains(where: { $0.archetype == .heavy }), "Warden Gate retains Heavy route guard")
        expectV24Traversal(gate.enemySpawns.contains(where: { $0.archetype == .ranged }), "Warden Gate retains deliberate ranged position")

        // Final fight is a clean arena, not another platform obstacle course.
        expectV24Traversal(
            chamber.platforms.contains(where: { $0.size.width >= 1100 && $0.size.height >= 70 && top($0) <= 110 }),
            "Warden Chamber has a broad uninterrupted arena floor"
        )
        expectV24Traversal(
            !chamber.platforms.contains(where: { $0.size.height <= 30 && $0.size.width >= 100 && $0.size.width <= 500 && top($0) > 150 }),
            "Warden Chamber has no small catch platform in the boss movement space"
        )

        print("V24MandatoryTraversalTests: PASS")
    }
}
