import Foundation

enum ApproachAtmosphereLayeringPolicy {
    static let hostNodeName = "worldRoot"
    static let atmosphereNodeName = "approachAtmosphereRoot"
    static let farNodeName = "approachAtmosphereFar"
    static let midNodeName = "approachAtmosphereMid"
    static let hazeNodeName = "approachAtmosphereHaze"

    // worldRoot contains the legacy backdrop at -100 and pillars at -50.
    // Keeping the atmosphere at -48 places it above those visuals while
    // remaining below roomGeometry (0/1), enemies, and the player.
    static let rootZPosition: Double = -48

    static let farParallax: Double = 0.10
    static let midParallax: Double = 0.24
    static let hazeParallax: Double = 0.46
    static let roomCenterX: Double = 600
}
