import Foundation

struct ApproachAtmosphereLayout: Equatable {
    struct Block: Equatable {
        let centerX: Double
        let centerY: Double
        let width: Double
        let height: Double
        let cornerRadius: Double
        let rotation: Double
    }

    struct FogBand: Equatable {
        let centerY: Double
        let width: Double
        let height: Double
        let drift: Double
        let alpha: Double
    }

    struct AshSeed: Equatable {
        let x: Double
        let y: Double
        let radius: Double
        let driftX: Double
        let driftY: Double
        let duration: Double
        let delay: Double
        let alpha: Double
    }

    let roomWidth: Double
    let roomHeight: Double

    let farStructures: [Block]
    let midStructures: [Block]
    let foregroundDebris: [Block]
    let fogBands: [FogBand]
    let ashSeeds: [AshSeed]

    let startShelter: Block
    let jumpBeacon: Block
    let enemyPool: Block
    let dropShaft: Block

    let farParallax: Double
    let midParallax: Double
    let hazeParallax: Double

    static func make(roomWidth: Double, roomHeight: Double) -> ApproachAtmosphereLayout {
        let width = max(1, roomWidth)
        let height = max(1, roomHeight)

        func x(_ ratio: Double) -> Double { width * ratio }
        func y(_ ratio: Double) -> Double { height * ratio }
        func w(_ ratio: Double) -> Double { width * ratio }
        func h(_ ratio: Double) -> Double { height * ratio }

        let farStructures: [Block] = [
            Block(centerX: x(0.06), centerY: y(0.48), width: w(0.10), height: h(0.72), cornerRadius: 18, rotation: -0.03),
            Block(centerX: x(0.19), centerY: y(0.42), width: w(0.075), height: h(0.58), cornerRadius: 14, rotation: 0.025),
            Block(centerX: x(0.34), centerY: y(0.54), width: w(0.11), height: h(0.80), cornerRadius: 20, rotation: -0.018),
            Block(centerX: x(0.50), centerY: y(0.45), width: w(0.065), height: h(0.62), cornerRadius: 12, rotation: 0.035),
            Block(centerX: x(0.64), centerY: y(0.52), width: w(0.12), height: h(0.76), cornerRadius: 22, rotation: -0.022),
            Block(centerX: x(0.79), centerY: y(0.43), width: w(0.07), height: h(0.60), cornerRadius: 14, rotation: 0.02),
            Block(centerX: x(0.91), centerY: y(0.55), width: w(0.10), height: h(0.84), cornerRadius: 18, rotation: -0.04)
        ]

        let midStructures: [Block] = [
            Block(centerX: x(0.03), centerY: y(0.29), width: w(0.12), height: h(0.34), cornerRadius: 10, rotation: 0.02),
            Block(centerX: x(0.15), centerY: y(0.26), width: w(0.085), height: h(0.25), cornerRadius: 9, rotation: -0.04),
            Block(centerX: x(0.29), centerY: y(0.31), width: w(0.10), height: h(0.36), cornerRadius: 11, rotation: 0.025),
            Block(centerX: x(0.43), centerY: y(0.25), width: w(0.075), height: h(0.22), cornerRadius: 8, rotation: -0.05),
            Block(centerX: x(0.57), centerY: y(0.30), width: w(0.11), height: h(0.34), cornerRadius: 11, rotation: 0.035),
            Block(centerX: x(0.71), centerY: y(0.26), width: w(0.08), height: h(0.24), cornerRadius: 8, rotation: -0.035),
            Block(centerX: x(0.84), centerY: y(0.34), width: w(0.12), height: h(0.42), cornerRadius: 12, rotation: 0.02),
            Block(centerX: x(0.96), centerY: y(0.31), width: w(0.08), height: h(0.38), cornerRadius: 10, rotation: -0.02)
        ]

        let debrisRatios: [(Double, Double, Double, Double, Double)] = [
            (0.045, 0.075, 0.06, 0.035, -0.14),
            (0.14, 0.085, 0.075, 0.04, 0.08),
            (0.245, 0.072, 0.05, 0.032, -0.06),
            (0.36, 0.082, 0.07, 0.038, 0.10),
            (0.49, 0.07, 0.055, 0.03, -0.11),
            (0.61, 0.084, 0.08, 0.04, 0.06),
            (0.72, 0.072, 0.05, 0.03, -0.09),
            (0.82, 0.086, 0.075, 0.038, 0.13),
            (0.91, 0.073, 0.06, 0.035, -0.08),
            (0.975, 0.082, 0.045, 0.034, 0.12)
        ]
        let foregroundDebris = debrisRatios.map { item in
            Block(
                centerX: x(item.0),
                centerY: y(item.1),
                width: w(item.2),
                height: h(item.3),
                cornerRadius: 5,
                rotation: item.4
            )
        }

        let fogBands: [FogBand] = [
            FogBand(centerY: y(0.22), width: w(1.30), height: h(0.13), drift: w(0.032), alpha: 0.13),
            FogBand(centerY: y(0.43), width: w(1.45), height: h(0.17), drift: w(0.024), alpha: 0.085),
            FogBand(centerY: y(0.67), width: w(1.35), height: h(0.14), drift: w(0.018), alpha: 0.055)
        ]

        var ashSeeds: [AshSeed] = []
        for index in 0..<36 {
            let pseudoA = (index * 37 + 11) % 101
            let pseudoB = (index * 53 + 17) % 97
            let pseudoC = (index * 29 + 7) % 89
            ashSeeds.append(
                AshSeed(
                    x: width * (Double(pseudoA) / 100.0),
                    y: height * (0.10 + 0.82 * Double(pseudoB) / 96.0),
                    radius: 0.9 + Double(pseudoC % 5) * 0.42,
                    driftX: 16 + Double((index * 13) % 31),
                    driftY: 30 + Double((index * 19) % 48),
                    duration: 4.6 + Double((index * 7) % 23) * 0.12,
                    delay: Double((index * 11) % 29) * 0.11,
                    alpha: 0.16 + Double((index * 5) % 10) * 0.025
                )
            )
        }

        return ApproachAtmosphereLayout(
            roomWidth: roomWidth,
            roomHeight: roomHeight,
            farStructures: farStructures,
            midStructures: midStructures,
            foregroundDebris: foregroundDebris,
            fogBands: fogBands,
            ashSeeds: ashSeeds,
            startShelter: Block(
                centerX: x(0.105), centerY: y(0.26), width: w(0.20), height: h(0.42),
                cornerRadius: 16, rotation: 0
            ),
            jumpBeacon: Block(
                centerX: x(0.375), centerY: y(0.41), width: w(0.24), height: h(0.57),
                cornerRadius: 20, rotation: 0
            ),
            enemyPool: Block(
                centerX: x(0.66), centerY: y(0.22), width: w(0.22), height: h(0.20),
                cornerRadius: 18, rotation: 0
            ),
            dropShaft: Block(
                centerX: x(0.93), centerY: y(0.22), width: w(0.17), height: h(0.42),
                cornerRadius: 12, rotation: 0
            ),
            farParallax: 0.10,
            midParallax: 0.24,
            hazeParallax: 0.46
        )
    }
}
