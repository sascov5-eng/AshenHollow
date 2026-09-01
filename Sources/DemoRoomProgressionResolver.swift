import Foundation

enum DemoRoomProgressionResolver {
    static func shrineToActivate(
        in room: RoomDefinition,
        playerCenter: RoomPoint,
        playerSize: RoomSize,
        consumedShrines: Set<ShrineID>
    ) -> AbilityShrinePlacement? {
        guard let shrine = room.shrine,
              !consumedShrines.contains(shrine.id) else {
            return nil
        }

        let activation = RoomRect(
            x: shrine.position.x - 48,
            y: shrine.position.y - 60,
            width: 96,
            height: 120
        )

        return activation.intersects(
            playerRect(center: playerCenter, size: playerSize)
        ) ? shrine : nil
    }

    static func checkpointToActivate(
        in room: RoomDefinition,
        playerCenter: RoomPoint,
        playerSize: RoomSize,
        currentCheckpoint: CheckpointSnapshot
    ) -> CheckpointSnapshot? {
        let player = playerRect(center: playerCenter, size: playerSize)
        return room.checkpointTriggers.first(where: {
            $0.checkpoint != currentCheckpoint && $0.trigger.intersects(player)
        })?.checkpoint
    }

    private static func playerRect(
        center: RoomPoint,
        size: RoomSize
    ) -> RoomRect {
        RoomRect(
            x: center.x - size.width * 0.5,
            y: center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
    }
}
