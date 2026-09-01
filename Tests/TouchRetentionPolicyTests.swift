import Foundation

@inline(__always)
func expectRetention(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct TouchRetentionPolicyTestsMain {
    static func main() {
        expectRetention(
            TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 55,
                baseRadius: 56
            ),
            "touch inside base radius is retained"
        )
        expectRetention(
            TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 78,
                baseRadius: 56
            ),
            "small drift beyond base radius is retained"
        )
        expectRetention(
            !TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 82,
                baseRadius: 56
            ),
            "touch beyond tolerance is released"
        )
        expectRetention(
            !TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 1,
                baseRadius: 0
            ),
            "non-positive base radius cannot retain a touch"
        )
        print("TouchRetentionPolicyTests: PASS")
    }
}
