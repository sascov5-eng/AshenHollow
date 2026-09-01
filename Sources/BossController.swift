import Foundation

enum BossPhase: Equatable {
    case one
    case two
    case defeated
}

enum BossPattern: Equatable, CaseIterable {
    case slash
    case charge
    case volley
}

enum BossPatternStage: Equatable {
    case idle
    case telegraph
    case committed
    case recovery
    case staggered
}

enum BossHitResponse: Equatable {
    case accepted
    case blocked
    case staggered
    case defeated
}

struct BossController {
    private(set) var hp: Int = 20
    private(set) var phase: BossPhase = .one
    private(set) var currentPattern: BossPattern?
    private(set) var stage: BossPatternStage = .idle
    private(set) var staggerHitCount: Int = 0

    private var stageRemaining: TimeInterval = 0
    private let staggerDuration: TimeInterval = 1.45

    var isCommitted: Bool { stage == .committed }
    var isAlive: Bool { phase != .defeated && hp > 0 }
    var volleyProjectileCount: Int { phase == .two ? 5 : 3 }
    private var staggerThreshold: Int { phase == .two ? 7 : 6 }

    func telegraphDuration(for pattern: BossPattern) -> TimeInterval {
        switch pattern {
        case .slash: return phase == .two ? 0.30 : 0.38
        case .charge: return phase == .two ? 0.38 : 0.50
        case .volley: return phase == .two ? 0.42 : 0.55
        }
    }

    func committedDuration(for pattern: BossPattern) -> TimeInterval {
        switch pattern {
        case .slash: return 0.18
        case .charge: return phase == .two ? 0.62 : 0.56
        case .volley: return phase == .two ? 0.34 : 0.28
        }
    }

    func recoveryDuration(for pattern: BossPattern) -> TimeInterval {
        let base: TimeInterval
        switch pattern {
        case .slash: base = 0.76
        case .charge: base = 0.98
        case .volley: base = 1.10
        }
        return phase == .two ? base * 0.74 : base
    }

    @discardableResult
    mutating func begin(pattern: BossPattern) -> Bool {
        guard isAlive, stage == .idle else { return false }
        currentPattern = pattern
        stage = .telegraph
        stageRemaining = telegraphDuration(for: pattern)
        return true
    }

    @discardableResult
    mutating func applyPlayerHit(damage: Int) -> BossHitResponse {
        guard isAlive, damage > 0 else { return .blocked }

        let wasStaggered = stage == .staggered
        let previousPhase = phase
        hp = max(0, hp - damage)

        if hp == 0 {
            phase = .defeated
            currentPattern = nil
            stage = .idle
            stageRemaining = 0
            staggerHitCount = 0
            return .defeated
        }

        if previousPhase == .one, hp <= 10 {
            phase = .two
            staggerHitCount = 0
            return .accepted
        }

        if wasStaggered {
            return .accepted
        }

        staggerHitCount += 1
        if staggerHitCount >= staggerThreshold {
            currentPattern = nil
            stage = .staggered
            stageRemaining = staggerDuration
            return .staggered
        }

        return .accepted
    }

    mutating func update(dt: TimeInterval) {
        guard isAlive, dt > 0, stage != .idle else { return }

        if stage == .staggered {
            stageRemaining = max(0, stageRemaining - dt)
            if stageRemaining == 0 {
                stage = .idle
                currentPattern = nil
                staggerHitCount = 0
            }
            return
        }

        guard let pattern = currentPattern else {
            stage = .idle
            stageRemaining = 0
            return
        }

        var remainingDT = dt
        while remainingDT > 0, stage != .idle, stage != .staggered, isAlive {
            if remainingDT < stageRemaining {
                stageRemaining -= remainingDT
                break
            }

            remainingDT -= stageRemaining
            advanceStage(for: pattern)
        }
    }

    private mutating func advanceStage(for pattern: BossPattern) {
        switch stage {
        case .idle:
            stageRemaining = 0
        case .telegraph:
            stage = .committed
            stageRemaining = committedDuration(for: pattern)
        case .committed:
            stage = .recovery
            stageRemaining = recoveryDuration(for: pattern)
        case .recovery:
            stage = .idle
            currentPattern = nil
            stageRemaining = 0
        case .staggered:
            break
        }
    }
}
