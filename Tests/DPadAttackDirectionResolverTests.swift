import Foundation

@inline(__always)
func expectDPad(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DPadAttackDirectionResolverTestsMain {
    static func main() {
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: false,
                downHeld: false,
                isGrounded: true
            ) == .horizontal,
            "no vertical modifier gives horizontal attack"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: true,
                downHeld: false,
                isGrounded: true
            ) == .up,
            "UP gives up-slash"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: false,
                downHeld: true,
                isGrounded: false
            ) == .down,
            "airborne DOWN gives down-slash"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: false,
                downHeld: true,
                isGrounded: true
            ) == .horizontal,
            "grounded DOWN falls back to horizontal"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: true,
                downHeld: true,
                isGrounded: false
            ) == .up,
            "UP wins deterministic conflict"
        )
        print("DPadAttackDirectionResolverTests: PASS")
    }
}
