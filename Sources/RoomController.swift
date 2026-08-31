import Foundation

enum RoomID: String, Equatable, Hashable {
    case entry
    case combat
}

struct RoomPoint: Equatable {
    let x: Double
    let y: Double
}

struct RoomSize: Equatable {
    let width: Double
    let height: Double
}

struct RoomRect: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var minX: Double { x }
    var maxX: Double { x + width }
    var minY: Double { y }
    var maxY: Double { y + height }

    func intersects(_ other: RoomRect) -> Bool {
        maxX > other.minX &&
        minX < other.maxX &&
        maxY > other.minY &&
        minY < other.maxY
    }
}

struct RoomPlatform: Equatable {
    let center: RoomPoint
    let size: RoomSize
}

struct RoomExit: Equatable {
    let trigger: RoomRect
    let destinationRoomID: RoomID
    let destinationSpawn: RoomPoint
}

struct RoomDefinition: Equatable {
    let id: RoomID
    let bounds: RoomRect
    let playerSpawn: RoomPoint
    let platforms: [RoomPlatform]
    let enemySpawn: RoomPoint?
    let exits: [RoomExit]
}

struct RoomTransition: Equatable {
    let destinationRoomID: RoomID
    let destinationSpawn: RoomPoint
}

struct RoomController {
    let initialRoomID: RoomID
    private let definitions: [RoomID: RoomDefinition]

    init(initialRoomID: RoomID, definitions: [RoomDefinition]) {
        self.initialRoomID = initialRoomID
        self.definitions = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    func room(_ id: RoomID) -> RoomDefinition? {
        definitions[id]
    }

    func transitionIfNeeded(
        playerCenter: RoomPoint,
        playerSize: RoomSize,
        in roomID: RoomID
    ) -> RoomTransition? {
        guard let room = definitions[roomID] else { return nil }

        let playerRect = RoomRect(
            x: playerCenter.x - playerSize.width * 0.5,
            y: playerCenter.y - playerSize.height * 0.5,
            width: playerSize.width,
            height: playerSize.height
        )

        guard let exit = room.exits.first(where: { $0.trigger.intersects(playerRect) }) else {
            return nil
        }

        return RoomTransition(
            destinationRoomID: exit.destinationRoomID,
            destinationSpawn: exit.destinationSpawn
        )
    }

    func clampedCameraX(
        targetX: Double,
        visibleHalfWidth: Double,
        in roomID: RoomID
    ) -> Double {
        guard let room = definitions[roomID] else { return targetX }

        let minCameraX = room.bounds.minX + visibleHalfWidth
        let maxCameraX = room.bounds.maxX - visibleHalfWidth

        if maxCameraX < minCameraX {
            return (room.bounds.minX + room.bounds.maxX) * 0.5
        }

        return max(minCameraX, min(maxCameraX, targetX))
    }

    static func makeV20TestLayout() -> RoomController {
        let roomA = RoomDefinition(
            id: .entry,
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                RoomPlatform(
                    center: RoomPoint(x: 600, y: 60),
                    size: RoomSize(width: 1200, height: 80)
                ),
                RoomPlatform(
                    center: RoomPoint(x: 520, y: 190),
                    size: RoomSize(width: 260, height: 28)
                ),
                RoomPlatform(
                    center: RoomPoint(x: 900, y: 255),
                    size: RoomSize(width: 230, height: 28)
                )
            ],
            enemySpawn: nil,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 1128, y: 100, width: 72, height: 160),
                    destinationRoomID: .combat,
                    destinationSpawn: RoomPoint(x: 110, y: 130)
                )
            ]
        )

        let roomB = RoomDefinition(
            id: .combat,
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 110, y: 130),
            platforms: [
                RoomPlatform(
                    center: RoomPoint(x: 600, y: 60),
                    size: RoomSize(width: 1200, height: 80)
                ),
                RoomPlatform(
                    center: RoomPoint(x: 120, y: 175),
                    size: RoomSize(width: 310, height: 28)
                ),
                RoomPlatform(
                    center: RoomPoint(x: 540, y: 235),
                    size: RoomSize(width: 260, height: 28)
                )
            ],
            enemySpawn: RoomPoint(x: 760, y: 130),
            exits: []
        )

        return RoomController(
            initialRoomID: .entry,
            definitions: [roomA, roomB]
        )
    }
}
