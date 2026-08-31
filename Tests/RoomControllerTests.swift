import Foundation

@inline(__always)
func expectRoom(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct RoomControllerTestsMain {
    static func main() {
        let controller = RoomController.makeV20TestLayout()
        expectRoom(controller.initialRoomID == .entry, "Room A is initial")

        let roomA = controller.room(.entry)
        let roomB = controller.room(.combat)
        expectRoom(roomA != nil, "Room A exists")
        expectRoom(roomB != nil, "Room B exists")
        expectRoom(roomA!.bounds.width == 1200, "Room A width is 1200")
        expectRoom(roomB!.bounds.width == 1200, "Room B width is 1200")
        expectRoom(roomA!.platforms[1].center != roomB!.platforms[1].center, "rooms use different geometry")
        expectRoom(roomB!.platforms[1].center == RoomPoint(x: 120, y: 175), "Room B first raised platform matches stable backing geometry")
        expectRoom(roomA!.enemySpawn == nil, "Room A is traversal-only so combat state cannot be consumed before Room B")
        expectRoom(roomB!.enemySpawn == RoomPoint(x: 760, y: 130), "Room B owns the V20 combat enemy")

        let noTransition = controller.transitionIfNeeded(
            playerCenter: RoomPoint(x: 500, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .entry
        )
        expectRoom(noTransition == nil, "middle of room does not transition")

        let transition = controller.transitionIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .entry
        )
        expectRoom(transition?.destinationRoomID == .combat, "Room A exit targets Room B")
        expectRoom(transition?.destinationSpawn == RoomPoint(x: 110, y: 130), "Room B spawn matches design")

        let leftClamp = controller.clampedCameraX(targetX: -500, visibleHalfWidth: 300, in: .entry)
        let rightClamp = controller.clampedCameraX(targetX: 5000, visibleHalfWidth: 300, in: .entry)
        expectRoom(leftClamp == 300, "camera clamps to Room A left edge")
        expectRoom(rightClamp == 900, "camera clamps to Room A right edge")

        print("RoomControllerTests: PASS")
    }
}
