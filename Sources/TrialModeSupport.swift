import Foundation
import CoreGraphics

enum TrialRank: String, CaseIterable, Codable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
}

struct TrialDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let startX: CGFloat
    let finishX: CGFloat
    let finishY: CGFloat
    let rankA: TimeInterval
    let rankB: TimeInterval
    let rankC: TimeInterval

    var finishRect: CGRect {
        CGRect(x: finishX - 70, y: finishY - 120, width: 140, height: 240)
    }

    var minX: CGFloat { min(startX, finishX) - 180 }
    var maxX: CGFloat { max(startX, finishX) + 180 }

    func rank(elapsed: TimeInterval, damageTaken: Int) -> TrialRank {
        let scoredTime = max(0, elapsed) + TimeInterval(max(0, damageTaken)) * 5.0
        if scoredTime <= rankA { return .a }
        if scoredTime <= rankB { return .b }
        if scoredTime <= rankC { return .c }
        return .d
    }
}

struct TrialRunResult: Equatable {
    let trialID: String
    let elapsed: TimeInterval
    let damageTaken: Int
    let enemiesDefeated: Int
    let rank: TrialRank
}

enum TrialCatalog {
    static let all: [TrialDefinition] = [
        TrialDefinition(id: "steps", title: "ПЕРВЫЕ ШАГИ", subtitle: "Прыжки • шипы • платформы", startX: 220, finishX: 2050, finishY: 170, rankA: 38, rankB: 55, rankC: 80),
        TrialDefinition(id: "hunt", title: "ОХОТА", subtitle: "Бой • СВЕТ • лечение", startX: 2200, finishX: 4050, finishY: 170, rankA: 45, rankB: 65, rankC: 95),
        TrialDefinition(id: "mechanism", title: "МЕХАНИЗМ", subtitle: "Рычаг • дверь • секрет", startX: 3920, finishX: 5550, finishY: 170, rankA: 42, rankB: 62, rankC: 92),
        TrialDefinition(id: "dash", title: "РЫВОК", subtitle: "Стены • рывок • яма", startX: 5350, finishX: 7040, finishY: 210, rankA: 40, rankB: 60, rankC: 90),
        TrialDefinition(id: "mixed", title: "СМЕШАННЫЙ БОЙ", subtitle: "Платформинг + враги", startX: 6900, finishX: 8200, finishY: 200, rankA: 42, rankB: 62, rankC: 90),
        TrialDefinition(id: "final", title: "ФИНАЛЬНОЕ ИСПЫТАНИЕ", subtitle: "Полный маршрут", startX: 220, finishX: 8420, finishY: 220, rankA: 145, rankB: 205, rankC: 285)
    ]

    static var first: TrialDefinition { all[0] }

    static func definition(id: String) -> TrialDefinition {
        all.first(where: { $0.id == id }) ?? first
    }
}

enum TrialProgressStore {
    private static let prefix = "ashenhollow.trial.best."

    static func bestTime(for trialID: String, defaults: UserDefaults = .standard) -> TimeInterval? {
        let key = prefix + trialID
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    static func save(_ result: TrialRunResult, defaults: UserDefaults = .standard) {
        let key = prefix + result.trialID
        if let current = bestTime(for: result.trialID, defaults: defaults), current <= result.elapsed { return }
        defaults.set(result.elapsed, forKey: key)
        defaults.set(result.rank.rawValue, forKey: key + ".rank")
    }

    static func bestRank(for trialID: String, defaults: UserDefaults = .standard) -> TrialRank? {
        guard let raw = defaults.string(forKey: prefix + trialID + ".rank") else { return nil }
        return TrialRank(rawValue: raw)
    }
}

enum DemoSettingsStore {
    static let musicVolumeKey = "ashenhollow.settings.musicVolume"
    static let effectsVolumeKey = "ashenhollow.settings.effectsVolume"
    static let vibrationEnabledKey = "ashenhollow.settings.vibrationEnabled"

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            musicVolumeKey: 0.75,
            effectsVolumeKey: 0.85,
            vibrationEnabledKey: true
        ])
    }
}
