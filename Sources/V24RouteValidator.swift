import Foundation

enum V24RouteValidationResult: Equatable {
    case safe
    case unsafe(String)
}

struct V24RouteValidationReport: Equatable {
    let roomResults: [RoomID: V24RouteValidationResult]
}

struct V24RouteValidator {
    let tuning: PlayerMovementTuning

    private let ordinaryValidator: TraversalSafetyValidator

    init(tuning: PlayerMovementTuning) {
        self.tuning = tuning
        self.ordinaryValidator = TraversalSafetyValidator(tuning: tuning)
    }

    func validate(level: RoomController) -> V24RouteValidationReport {
        let rooms: [RoomID] = [
            .approach, .lowerHall, .brokenGallery, .dashShrine,
            .furnacePassage, .watcherHall, .hollowShaft,
            .ashenAscent, .wardenGate, .wardenChamber
        ]

        var results: [RoomID: V24RouteValidationResult] = [:]
        for roomID in rooms {
            results[roomID] = validate(roomID: roomID, level: level)
        }
        return V24RouteValidationReport(roomResults: results)
    }

    private func validate(roomID: RoomID, level: RoomController) -> V24RouteValidationResult {
        guard let room = level.room(roomID) else {
            return .unsafe("missing room")
        }
        guard let route = V24MandatoryRoute.manifest(for: roomID) else {
            return .unsafe("missing mandatory route manifest")
        }
        guard !route.steps.isEmpty else {
            return .unsafe("empty mandatory route")
        }
        guard room.exits.indices.contains(route.exitIndex) else {
            return .unsafe("route references missing exit")
        }

        for step in route.steps where !room.platforms.indices.contains(step.platformIndex) {
            return .unsafe("route references missing platform \(step.platformIndex)")
        }

        let first = room.platforms[route.steps[0].platformIndex]
        if !spawnIsSupported(room.playerSpawn, by: first) {
            return .unsafe("player spawn is not supported by first route surface")
        }

        if route.steps.count > 1 {
            for index in 1..<route.steps.count {
                let previousStep = route.steps[index - 1]
                let step = route.steps[index]
                let source = room.platforms[previousStep.platformIndex]
                let target = room.platforms[step.platformIndex]

                if let failure = validateTransfer(
                    step.transfer,
                    source: source,
                    target: target,
                    room: room
                ) {
                    return .unsafe("step \(index): \(failure)")
                }
            }
        }

        let last = room.platforms[route.steps.last!.platformIndex]
        let exit = room.exits[route.exitIndex]
        if !exitIsReachable(exit.trigger, from: last) {
            return .unsafe("exit is disconnected from final route surface")
        }

        return .safe
    }

    private func validateTransfer(
        _ transfer: V24RouteTransfer,
        source: RoomPlatform,
        target: RoomPlatform,
        room: RoomDefinition
    ) -> String? {
        switch transfer {
        case .spawn:
            return nil
        case .ordinary:
            switch ordinaryValidator.validateOrdinaryTransfer(from: source, to: target) {
            case .safe:
                return nil
            case let .unsafe(reason):
                return reason
            }
        case .dash:
            return validateDash(source: source, target: target)
        case .drop:
            return validateDrop(source: source, target: target)
        case .wallJump:
            return validateWallTraversal(target: target, room: room, needsDashFinish: false)
        case .wallJumpDash:
            return validateWallTraversal(target: target, room: room, needsDashFinish: true)
        }
    }

    private func validateDash(source: RoomPlatform, target: RoomPlatform) -> String? {
        let rise = top(target) - top(source)
        if abs(rise) > 20 {
            return "Dash transfer changes landing height by more than 20 pt"
        }
        if target.size.width < 260 {
            return "Dash landing is narrower than 260 pt"
        }

        let gap = clearGap(source, target)
        if gap < 180 {
            return "Dash transfer is not meaningfully beyond conservative ordinary-jump spacing"
        }
        if gap > 255 {
            return "Dash transfer exceeds first-play Dash envelope"
        }
        return nil
    }

    private func validateDrop(source: RoomPlatform, target: RoomPlatform) -> String? {
        if top(target) > top(source) + 5 {
            return "drop target is above source"
        }
        if horizontalOverlap(source, target) < 50 {
            return "drop has less than 50 pt of horizontal capture overlap"
        }
        return nil
    }

    private func validateWallTraversal(
        target: RoomPlatform,
        room: RoomDefinition,
        needsDashFinish: Bool
    ) -> String? {
        if target.size.width < 240 {
            return "wall traversal recovery is narrower than 240 pt"
        }

        let walls = room.platforms
            .filter { $0.size.width <= 50 && $0.size.height >= 120 }
            .sorted { $0.center.x < $1.center.x }

        var hasSafePair = false
        if walls.count >= 2 {
            for index in 0..<(walls.count - 1) {
                let gap = minX(walls[index + 1]) - maxX(walls[index])
                if gap >= 170 && gap <= 200 {
                    hasSafePair = true
                    break
                }
            }
        }
        if !hasSafePair {
            return "room has no 170–200 pt opposing wall pair"
        }

        if needsDashFinish && target.size.width < 280 {
            return "wall+jump+Dash recovery is narrower than 280 pt"
        }
        return nil
    }

    private func spawnIsSupported(_ spawn: RoomPoint, by platform: RoomPlatform) -> Bool {
        let halfCollider = tuning.colliderWidth * 0.5
        let expectedCenterY = top(platform) + tuning.colliderHeight * 0.5
        return spawn.x >= minX(platform) + halfCollider &&
            spawn.x <= maxX(platform) - halfCollider &&
            abs(spawn.y - expectedCenterY) <= 8
    }

    private func exitIsReachable(_ trigger: RoomRect, from platform: RoomPlatform) -> Bool {
        let platformRect = RoomRect(
            x: minX(platform),
            y: platform.center.y - platform.size.height * 0.5,
            width: platform.size.width,
            height: platform.size.height
        )

        let dx = max(0, max(trigger.minX - platformRect.maxX, platformRect.minX - trigger.maxX))
        let dy = max(0, max(trigger.minY - platformRect.maxY, platformRect.minY - trigger.maxY))
        return dx <= 80 && dy <= 100
    }

    private func clearGap(_ a: RoomPlatform, _ b: RoomPlatform) -> Double {
        if b.center.x >= a.center.x {
            return max(0, minX(b) - maxX(a))
        }
        return max(0, minX(a) - maxX(b))
    }

    private func horizontalOverlap(_ a: RoomPlatform, _ b: RoomPlatform) -> Double {
        max(0, min(maxX(a), maxX(b)) - max(minX(a), minX(b)))
    }

    private func minX(_ platform: RoomPlatform) -> Double {
        platform.center.x - platform.size.width * 0.5
    }

    private func maxX(_ platform: RoomPlatform) -> Double {
        platform.center.x + platform.size.width * 0.5
    }

    private func top(_ platform: RoomPlatform) -> Double {
        platform.center.y + platform.size.height * 0.5
    }
}
