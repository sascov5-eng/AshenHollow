import Foundation

enum V24RouteTransfer: Equatable {
    case spawn
    case ordinary
    case dash
    case drop
    case wallJump
    case wallJumpDash
}

struct V24RouteStep: Equatable {
    let platformIndex: Int
    let transfer: V24RouteTransfer
}

struct V24MandatoryRoute: Equatable {
    let roomID: RoomID
    let exitIndex: Int
    let steps: [V24RouteStep]

    static func manifest(for roomID: RoomID) -> V24MandatoryRoute? {
        switch roomID {
        case .approach:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [
                    V24RouteStep(platformIndex: 0, transfer: .spawn),
                    V24RouteStep(platformIndex: 1, transfer: .ordinary),
                    V24RouteStep(platformIndex: 0, transfer: .drop)
                ]
            )
        case .lowerHall:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [
                    V24RouteStep(platformIndex: 0, transfer: .spawn),
                    V24RouteStep(platformIndex: 1, transfer: .drop),
                    V24RouteStep(platformIndex: 2, transfer: .drop)
                ]
            )
        case .brokenGallery:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [V24RouteStep(platformIndex: 0, transfer: .spawn)]
            )
        case .dashShrine:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [
                    V24RouteStep(platformIndex: 0, transfer: .spawn),
                    V24RouteStep(platformIndex: 1, transfer: .dash)
                ]
            )
        case .furnacePassage:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [
                    V24RouteStep(platformIndex: 0, transfer: .spawn),
                    V24RouteStep(platformIndex: 1, transfer: .dash),
                    V24RouteStep(platformIndex: 2, transfer: .ordinary),
                    V24RouteStep(platformIndex: 3, transfer: .ordinary)
                ]
            )
        case .watcherHall:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [V24RouteStep(platformIndex: 0, transfer: .spawn)]
            )
        case .hollowShaft:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [
                    V24RouteStep(platformIndex: 0, transfer: .spawn),
                    V24RouteStep(platformIndex: 3, transfer: .wallJump)
                ]
            )
        case .ashenAscent:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [
                    V24RouteStep(platformIndex: 0, transfer: .spawn),
                    V24RouteStep(platformIndex: 3, transfer: .wallJump),
                    V24RouteStep(platformIndex: 4, transfer: .dash),
                    V24RouteStep(platformIndex: 7, transfer: .wallJumpDash)
                ]
            )
        case .wardenGate:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [V24RouteStep(platformIndex: 0, transfer: .spawn)]
            )
        case .wardenChamber:
            return V24MandatoryRoute(
                roomID: roomID,
                exitIndex: 0,
                steps: [V24RouteStep(platformIndex: 0, transfer: .spawn)]
            )
        }
    }
}
