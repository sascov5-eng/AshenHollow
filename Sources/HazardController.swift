import Foundation
import CoreGraphics

enum HazardEvent: Equatable {
    case none
    case spikeDamage(hpLoss: Int)
    case death
}

enum HazardController {
    static let globalKillY: CGFloat = -220

    static func event(playerFrame: CGRect, playerY: CGFloat, layout: TestLocationSpec) -> HazardEvent {
        if playerY < globalKillY { return .death }
        for hazard in layout.hazards where hazard.rect.intersects(playerFrame) {
            switch hazard.kind {
            case .spikes: return .spikeDamage(hpLoss: 1)
            case .deathZone: return .death
            }
        }
        return .none
    }
}
