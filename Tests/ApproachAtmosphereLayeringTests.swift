import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ApproachAtmosphereLayeringTests {
    static func main() {
        expect(ApproachAtmosphereLayeringPolicy.hostNodeName == "worldRoot",
               "Approach atmosphere must live under worldRoot so the old opaque backdrop cannot cover it")
        expect(ApproachAtmosphereLayeringPolicy.atmosphereNodeName == "approachAtmosphereRoot",
               "policy must target the runtime atmosphere root")
        expect(ApproachAtmosphereLayeringPolicy.rootZPosition > -50,
               "atmosphere must render in front of the legacy background pillars")
        expect(ApproachAtmosphereLayeringPolicy.rootZPosition < 0,
               "atmosphere must remain behind room collision geometry")
        print("ApproachAtmosphereLayeringTests passed")
    }
}
