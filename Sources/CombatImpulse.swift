import Foundation

enum CombatImpulseKind: Equatable {
    case recoil
    case pogo
}

struct CombatImpulse: Equatable {
    let kind: CombatImpulseKind
    let velocityX: Double?
    let velocityY: Double?

    static func recoil(direction: Double, speed: Double = 240) -> CombatImpulse {
        CombatImpulse(
            kind: .recoil,
            velocityX: direction >= 0 ? abs(speed) : -abs(speed),
            velocityY: nil
        )
    }

    static func pogo(verticalSpeed: Double = 465) -> CombatImpulse {
        CombatImpulse(
            kind: .pogo,
            velocityX: nil,
            velocityY: abs(verticalSpeed)
        )
    }
}
