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

        // The perceived map must match the approved DOWN/LEFT/DOWN/LEFT/UP/LEFT/UP/LEFT/DOWN route.
        expectV24Traversal(approach.worldOrigin.x == lower.worldOrigin.x && approach.worldOrigin.y > lower.worldOrigin.y, "Approach is physically above Lower Hall")
        expectV24Traversal(lower.worldOrigin.y == gallery.worldOrigin.y && lower.worldOrigin.x > gallery.worldOrigin.x, "Broken Gallery is physically left of Lower Hall")
        expectV24Traversal(gallery.worldOrigin.x == dash.worldOrigin.x && gallery.worldOrigin.y > dash.worldOrigin.y, "Dash Shrine is physically below Broken Gallery")
        expectV24Traversal(dash.worldOrigin.y == furnace.worldOrigin.y && dash.worldOrigin.x > furnace.worldOrigin.x, "Furnace Passage is physically left of Dash Shrine")
        expectV24Traversal(furnace.worldOrigin.x == watcher.worldOrigin.x && furnace.worldOrigin.y < watcher.worldOrigin.y, "Watcher Hall is physically above Furnace Passage")
        expectV24Traversal(watcher.worldOrigin.y == shaft.worldOrigin.y && watcher.worldOrigin.x > shaft.worldOrigin.x, "Hollow Shaft is physically left of Watcher Hall")
        expectV24Traversal(shaft.worldOrigin.x == ascent.worldOrigin.x && shaft.worldOrigin.y < ascent.worldOrigin.y, "Ashen Ascent is physically above Hollow Shaft")
        expectV24Traversal(ascent.worldOrigin.y == gate.worldOrigin.y && ascent.worldOrigin.x > gate.worldOrigin.x, "Warden Gate is physically left of Ashen Ascent")
        expectV24Traversal(gate.worldOrigin.x == chamber.worldOrigin.x && gate.worldOrigin.y > chamber.worldOrigin.y, "Warden Chamber is physically below Warden Gate")

        // Approach onboarding jump: a low, wide ledge with first-play margin.
        let tutorialLedges = approach.platforms.filter {
            $0.size.height <= 30 && $0.size.width >= 240 && top($0) >= 150 && top($0) <= 180
        }
        expectV24Traversal(!tutorialLedges.isEmpty, "Approach has a wide 50–80 pt onboarding jump ledge")

        // Broken Gallery exposes the later high shortcut but keeps it optional.
        expectV24Traversal(
            gallery.exits.contains(where: { $0.requiredAbility == .wallTraversal && $0.destinationRoomID == .ashenAscent }),
            "Broken Gallery preserves the Wall Traversal shortcut payoff"
        )

        // Dash Shrine: one clear Dash gate with broad receiving bank and a recovery shelf.
        let dashSourceCandidates = dash.platforms.filter {
            $0.center.x > 700 && $0.size.width >= 350 && $0.size.height <= 30 && top($0) >= 150 && top($0) <= 170
        }
        let dashLandingCandidates = dash.platforms.filter {
            $0.center.x < 600 && $0.size.width >= 260 && $0.size.height <= 30 && top($0) >= 150 && top($0) <= 170
        }
        expectV24Traversal(dashSourceCandidates.count == 1, "Dash Shrine has one broad right-side takeoff bank")
        expectV24Traversal(dashLandingCandidates.count == 1, "Dash Shrine has one broad left-side receiving bank")
        if let source = dashSourceCandidates.first, let landing = dashLandingCandidates.first {
            expectV24Traversal(safe(validator.validateDashTeachingTransfer(from: source, to: landing)), "first Dash transfer is inside safe teaching envelope")

            let ascentSteps = dash.platforms.filter {
                $0.center.x < 300 && $0.size.width >= 220 && $0.size.height <= 30 && top($0) > top(landing)
            }.sorted { top($0) < top($1) }
            expectV24Traversal(!ascentSteps.isEmpty, "Dash Shrine has an easy post-landing ascent step")
            if let firstStep = ascentSteps.first {
                expectV24Traversal(safe(validator.validateVerticalStep(from: landing, to: firstStep)), "post-Dash ascent cannot catch the player on a platform side")
            }
        }
        expectV24Traversal(
            dash.platforms.contains(where: { $0.center.x > 800 && top($0) >= 70 && top($0) <= 100 && $0.size.width >= 140 }),
            "Dash Shrine has a source-side recovery shelf below the teaching gap"
        )

        // Hollow Shaft must be accessible before unlock and forgiving after it.
        expectV24Traversal(shaft.shrine?.ability == .wallTraversal, "Hollow Shaft still grants Wall Traversal")
        expectV24Traversal(shaft.shrine?.position.y <= 140, "Wall shrine remains walk-accessible on the lower floor")
        let walls = shaft.platforms
            .filter { $0.size.width <= 50 && $0.size.height >= 300 }
            .sorted { $0.center.x < $1.center.x }
        expectV24Traversal(walls.count == 2, "Hollow Shaft uses one clean opposing wall pair")
        if walls.count == 2 {
            let innerGap = minX(walls[1]) - maxX(walls[0])
            expectV24Traversal(innerGap >= 170 && innerGap <= 200, "Hollow Shaft inner wall gap is 170–200 pt")
            expectV24Traversal(walls.allSatisfy { ($0.center.y - $0.size.height * 0.5) >= 145 }, "climb walls start above the walk-accessible shrine floor")
        }
        expectV24Traversal(
            shaft.platforms.contains(where: { $0.size.width >= 220 && top($0) >= 510 }),
            "Hollow Shaft ends on a broad upper recovery ledge"
        )

        // Combined traversal must have stable recovery surfaces rather than one long precision chain.
        expectV24Traversal(
            ascent.platforms.filter { $0.size.width >= 240 && $0.size.height <= 30 }.count >= 2,
            "Ashen Ascent contains multiple broad recovery platforms"
        )
        expectV24Traversal(
            ascent.platforms.contains(where: { $0.size.width <= 50 && $0.size.height >= 200 }),
            "Ashen Ascent contains a deliberate wall-traversal surface"
        )

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
