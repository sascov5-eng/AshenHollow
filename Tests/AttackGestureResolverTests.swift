import Foundation

@inline(__always)
func expectGesture(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct AttackGestureResolverTestsMain {
    static func main() {
        expectGesture(
            AttackGestureResolver.resolve(deltaX: 4, deltaY: 8, isGrounded: true) == .horizontal,
            "small movement defaults to horizontal"
        )
        expectGesture(
            AttackGestureResolver.resolve(deltaX: 0, deltaY: -35, isGrounded: true) == .up,
            "upward swipe selects up attack"
        )
        expectGesture(
            AttackGestureResolver.resolve(deltaX: 0, deltaY: 35, isGrounded: false) == .down,
            "airborne downward swipe selects down attack"
        )
        expectGesture(
            AttackGestureResolver.resolve(deltaX: 0, deltaY: 35, isGrounded: true) == .horizontal,
            "grounded downward swipe falls back to horizontal"
        )

        print("AttackGestureResolverTests: PASS")
    }
}
