import Foundation

@inline(__always)
func expectRoomProgression(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DemoRoomProgressionResolverTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()
        let dashRoom = level.room(.dashShrine)!
        let dashPlacement = dashRoom.shrine!

        let shrineHit = DemoRoomProgressionResolver.shrineToActivate(
            in: dashRoom,
            playerCenter: dashPlacement.position,
            playerSize: RoomSize(width: 36, height: 60),
            consumedShrines: []
        )
        expectRoomProgression(shrineHit?.id == .dash, "player entering Dash shrine activates Dash placement")

        let consumedShrineHit = DemoRoomProgressionResolver.shrineToActivate(
            in: dashRoom,
            playerCenter: dashPlacement.position,
            playerSize: RoomSize(width: 36, height: 60),
            consumedShrines: [.dash]
        )
        expectRoomProgression(consumedShrineHit == nil, "consumed shrine cannot reactivate")

        let farShrineHit = DemoRoomProgressionResolver.shrineToActivate(
            in: dashRoom,
            playerCenter: RoomPoint(x: 1000, y: 400),
            playerSize: RoomSize(width: 36, height: 60),
            consumedShrines: []
        )
        expectRoomProgression(farShrineHit == nil, "player outside shrine activation rectangle does not activate shrine")

        let gate = level.room(.wardenGate)!
        let preWardenTrigger = gate.checkpointTriggers.first!
        let preWarden = preWardenTrigger.checkpoint
        let checkpointCenter = RoomPoint(
            x: preWardenTrigger.trigger.x + preWardenTrigger.trigger.width * 0.5,
            y: preWardenTrigger.trigger.y + preWardenTrigger.trigger.height * 0.5
        )
        let checkpointHit = DemoRoomProgressionResolver.checkpointToActivate(
            in: gate,
            playerCenter: checkpointCenter,
            playerSize: RoomSize(width: 36, height: 60),
            currentCheckpoint: DemoProgressionState.fresh.checkpoint
        )
        expectRoomProgression(checkpointHit == preWarden, "entering checkpoint trigger returns pre-Warden checkpoint")

        let duplicateCheckpointHit = DemoRoomProgressionResolver.checkpointToActivate(
            in: gate,
            playerCenter: checkpointCenter,
            playerSize: RoomSize(width: 36, height: 60),
            currentCheckpoint: preWarden
        )
        expectRoomProgression(duplicateCheckpointHit == nil, "active checkpoint does not persist repeatedly every frame")

        print("DemoRoomProgressionResolverTests: PASS")
    }
}
