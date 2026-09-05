import Foundation
import CoreGraphics

struct LargeWorldLayout {
    let bounds: CGRect
    let spawnPoint: CGPoint
    let collisionRects: [CGRect]
    let backgroundRects: [CGRect]
    let foregroundRects: [CGRect]

    static let blockout: LargeWorldLayout = {
        let bounds = CGRect(x: 0, y: 0, width: 7600, height: 1900)

        let collision: [CGRect] = [
            // Outer shell.
            CGRect(x: 0, y: 0, width: 80, height: 1900),
            CGRect(x: 7520, y: 0, width: 80, height: 1900),
            CGRect(x: 0, y: 1820, width: 7600, height: 80),

            // Starting cavern + long horizontal traversal. Floor height changes are deliberate.
            CGRect(x: 0, y: 0, width: 1050, height: 100),
            CGRect(x: 1050, y: 0, width: 850, height: 140),
            CGRect(x: 1900, y: 0, width: 900, height: 90),
            CGRect(x: 2800, y: 0, width: 850, height: 160),
            CGRect(x: 3650, y: 0, width: 800, height: 110),
            CGRect(x: 4450, y: 0, width: 680, height: 90),
            CGRect(x: 5130, y: 0, width: 2470, height: 80),

            // Cave ceiling masses form tunnels rather than isolated floating platforms.
            CGRect(x: 80, y: 590, width: 900, height: 360),
            CGRect(x: 1180, y: 650, width: 620, height: 300),
            CGRect(x: 2040, y: 560, width: 520, height: 390),
            CGRect(x: 2760, y: 720, width: 620, height: 230),
            CGRect(x: 3500, y: 640, width: 620, height: 310),

            // Open chamber architecture and traversal ledges.
            CGRect(x: 2940, y: 300, width: 330, height: 34),
            CGRect(x: 3380, y: 420, width: 300, height: 34),
            CGRect(x: 3770, y: 300, width: 260, height: 34),
            CGRect(x: 4050, y: 500, width: 280, height: 34),

            // Tall shaft walls. Bottom openings allow continuous entry from the chamber.
            CGRect(x: 4380, y: 330, width: 64, height: 1120),
            CGRect(x: 5060, y: 280, width: 64, height: 1270),

            // Alternating shaft ledges / wall-jump rests.
            CGRect(x: 4444, y: 360, width: 190, height: 26),
            CGRect(x: 4810, y: 560, width: 250, height: 26),
            CGRect(x: 4444, y: 760, width: 220, height: 26),
            CGRect(x: 4770, y: 960, width: 290, height: 26),
            CGRect(x: 4444, y: 1160, width: 230, height: 26),
            CGRect(x: 4770, y: 1360, width: 290, height: 26),

            // Upper route emerging from the shaft.
            CGRect(x: 5060, y: 1490, width: 720, height: 40),
            CGRect(x: 5900, y: 1410, width: 520, height: 40),
            CGRect(x: 6490, y: 1290, width: 430, height: 40),
            CGRect(x: 7010, y: 1160, width: 510, height: 40),

            // Descending continuation on the far side.
            CGRect(x: 6900, y: 970, width: 300, height: 32),
            CGRect(x: 7160, y: 770, width: 360, height: 32),
            CGRect(x: 6760, y: 580, width: 340, height: 32),
            CGRect(x: 7100, y: 390, width: 420, height: 32),
            CGRect(x: 6600, y: 220, width: 420, height: 32),

            // Extra architectural lips/choke points to break straight-line movement.
            CGRect(x: 900, y: 250, width: 220, height: 32),
            CGRect(x: 1510, y: 330, width: 260, height: 32),
            CGRect(x: 2240, y: 260, width: 260, height: 32),
            CGRect(x: 2620, y: 420, width: 220, height: 32),
            CGRect(x: 5700, y: 1180, width: 300, height: 32),
            CGRect(x: 6200, y: 1080, width: 300, height: 32)
        ]

        let background: [CGRect] = [
            CGRect(x: 260, y: 100, width: 260, height: 650),
            CGRect(x: 760, y: 100, width: 180, height: 520),
            CGRect(x: 1320, y: 140, width: 300, height: 690),
            CGRect(x: 2020, y: 90, width: 220, height: 540),
            CGRect(x: 2550, y: 90, width: 360, height: 760),
            CGRect(x: 3220, y: 160, width: 430, height: 930),
            CGRect(x: 3920, y: 110, width: 330, height: 780),
            CGRect(x: 4540, y: 90, width: 410, height: 1510),
            CGRect(x: 5230, y: 80, width: 520, height: 1580),
            CGRect(x: 6040, y: 80, width: 360, height: 1460),
            CGRect(x: 6700, y: 80, width: 460, height: 1320)
        ]

        let foreground: [CGRect] = [
            CGRect(x: 0, y: 0, width: 320, height: 72),
            CGRect(x: 1650, y: 0, width: 340, height: 68),
            CGRect(x: 3300, y: 0, width: 420, height: 76),
            CGRect(x: 5200, y: 0, width: 380, height: 70),
            CGRect(x: 7080, y: 0, width: 520, height: 74)
        ]

        return LargeWorldLayout(
            bounds: bounds,
            spawnPoint: CGPoint(x: 320, y: 160),
            collisionRects: collision,
            backgroundRects: background,
            foregroundRects: foreground
        )
    }()
}
