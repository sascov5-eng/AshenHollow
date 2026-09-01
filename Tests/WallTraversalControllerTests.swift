import Foundation

@inline(__always)
func expectWall(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct WallTraversalControllerTestsMain {
    static func main() {
        var wall = WallTraversalController()
        expectWall(wall.clingSide(unlocked: false, isGrounded: false, heldDirectionX: 1, contactSide: .right) == nil, "locked traversal cannot cling")
        expectWall(wall.clingSide(unlocked: true, isGrounded: true, heldDirectionX: 1, contactSide: .right) == nil, "ground contact wins over wall cling")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: -1, contactSide: .right) == nil, "holding away does not cling")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: 1, contactSide: .right) == .right, "holding into contacted wall clings")
        expectWall(wall.slideSpeed == -180, "wall slide speed cap is stable")

        let jump = wall.wallJump(from: .right)
        expectWall(jump.velocityX < 0, "right-wall jump pushes left")
        expectWall(jump.velocityY > 0, "wall jump pushes upward")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: 1, contactSide: .right) == nil, "same-wall lock blocks instant reattachment")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: -1, contactSide: .left) == .left, "opposite wall remains usable")
        wall.update(dt: 0.13)
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: 1, contactSide: .right) == .right, "same wall unlocks after lock duration")

        print("WallTraversalControllerTests: PASS")
    }
}
