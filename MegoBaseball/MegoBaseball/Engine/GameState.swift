import Foundation

/// The complete score, count and base situation of a game, plus the rules that change it.
/// Pure value type with no timing or UI so it can be unit tested.
struct GameState: Equatable, Codable {
    let regulationInnings: Int
    var inning = 1
    var half: Half = .top
    var balls = 0
    var strikes = 0
    var outs = 0
    /// Index 0 = first base, 1 = second, 2 = third.
    var bases = [false, false, false]
    /// Indexed by `Team.rawValue`.
    var score = [0, 0]
    var winner: Team?

    init(innings: Int = 9) {
        regulationInnings = max(1, innings)
    }

    var isOver: Bool { winner != nil }
    var battingTeam: Team { half == .top ? .visitor : .home }
    var fieldingTeam: Team { battingTeam.opponent }
    var hasRunners: Bool { bases.contains(true) }

    /// The base the runner who would try to steal is standing on, if any.
    /// Prefers a steal of second or third over a steal of home.
    var stealingRunnerBase: Int? {
        for base in [1, 0] where bases[base] && !bases[base + 1] {
            return base
        }
        return bases[2] ? 2 : nil
    }

    func score(of team: Team) -> Int { score[team.rawValue] }

    // MARK: - Applying a pitch

    @discardableResult
    mutating func apply<R: RandomNumberGenerator>(_ outcome: PitchOutcome, rng: inout R) -> [PlayEvent] {
        guard !isOver else { return [] }
        var events: [PlayEvent] = []

        switch outcome {
        case .take(strike: true):
            addStrike(swinging: false, events: &events)

        case .take(strike: false):
            balls += 1
            if balls >= 4 {
                events.append(.walk)
                resetCount()
                let runs = forceWalk()
                addRuns(runs, events: &events)
            } else {
                events.append(.ball)
            }

        case .swingAndMiss:
            addStrike(swinging: true, events: &events)

        case .contact(.foul(let spot)):
            if strikes < 2 { strikes += 1 }
            events.append(.foul(spot))

        case .contact(.hit(let kind, let spot)):
            events.append(.hit(kind, spot))
            resetCount()
            let runs = advanceRunners(by: kind.bases, batterReaches: true)
            addRuns(runs, events: &events)

        case .contact(.flyOut(let spot)):
            events.append(.out(spot, fly: true))
            resetCount()
            outs += 1
            if outs < 3 && bases[2] {
                // Runner on third tags up and scores.
                bases[2] = false
                events.append(.sacrificeFly)
                addRuns(1, events: &events)
            }
            retireSideIfNeeded(events: &events)

        case .contact(.groundOut(let spot)):
            resetCount()
            if bases[0] && outs < 2 && Double.random(in: 0..<1, using: &rng) < 0.5 {
                bases[0] = false
                outs += 2
                events.append(.doublePlay(spot))
            } else {
                outs += 1
                events.append(.out(spot, fly: false))
                if outs < 3 {
                    // Runners move up one base on the throw to first.
                    let runs = advanceRunners(by: 1, batterReaches: false)
                    addRuns(runs, events: &events)
                }
            }
            retireSideIfNeeded(events: &events)
        }

        return events
    }

    /// Settles a steal attempt made during a pitch that was not put in play.
    @discardableResult
    mutating func resolveSteal(success: Bool) -> [PlayEvent] {
        guard !isOver, outs < 3, let from = stealingRunnerBase else { return [] }
        var events: [PlayEvent] = []
        bases[from] = false
        if success {
            events.append(.stolenBase(to: from + 1))
            if from == 2 {
                addRuns(1, events: &events)
            } else {
                bases[from + 1] = true
            }
        } else {
            events.append(.caughtStealing)
            outs += 1
            retireSideIfNeeded(events: &events)
        }
        return events
    }

    /// Chance the current lead runner steals successfully on the given pitch.
    func stealChance(on pitch: PitchType) -> Double {
        guard let from = stealingRunnerBase else { return 0 }
        let base = pitch.stealSuccessChance
        switch from {
        case 2: return base * 0.45
        case 1: return base * 0.85
        default: return base
        }
    }

    // MARK: - Helpers

    private mutating func addStrike(swinging: Bool, events: inout [PlayEvent]) {
        strikes += 1
        if strikes >= 3 {
            events.append(.strikeout)
            resetCount()
            outs += 1
            retireSideIfNeeded(events: &events)
        } else {
            events.append(swinging ? .swingingStrike : .calledStrike)
        }
    }

    private mutating func resetCount() {
        balls = 0
        strikes = 0
    }

    /// Moves forced runners up one base and puts the batter on first. Returns runs scored.
    private mutating func forceWalk() -> Int {
        var runs = 0
        if bases[0] {
            if bases[1] {
                if bases[2] { runs += 1 }
                bases[2] = true
            }
            bases[1] = true
        }
        bases[0] = true
        return runs
    }

    /// Every runner moves up `count` bases. Returns runs scored.
    private mutating func advanceRunners(by count: Int, batterReaches: Bool) -> Int {
        var runs = 0
        var moved = [false, false, false]
        for base in 0..<3 where bases[base] {
            let target = base + count
            if target >= 3 { runs += 1 } else { moved[target] = true }
        }
        if batterReaches {
            if count >= 4 { runs += 1 } else { moved[count - 1] = true }
        }
        bases = moved
        return runs
    }

    private mutating func addRuns(_ runs: Int, events: inout [PlayEvent]) {
        guard runs > 0 else { return }
        score[battingTeam.rawValue] += runs
        events.append(.runsScored(runs))
        // Walk-off: home team takes the lead in the bottom of the last inning or later.
        if half == .bottom && inning >= regulationInnings && score(of: .home) > score(of: .visitor) {
            finish(winner: .home, events: &events)
        }
    }

    private mutating func retireSideIfNeeded(events: inout [PlayEvent]) {
        guard outs >= 3, !isOver else { return }
        events.append(.sideRetired)

        let visitor = score(of: .visitor)
        let home = score(of: .home)
        if half == .top {
            if inning >= regulationInnings && home > visitor {
                finish(winner: .home, events: &events)
                return
            }
            half = .bottom
        } else {
            if inning >= regulationInnings && home != visitor {
                finish(winner: home > visitor ? .home : .visitor, events: &events)
                return
            }
            half = .top
            inning += 1
        }
        outs = 0
        resetCount()
        bases = [false, false, false]
    }

    private mutating func finish(winner team: Team, events: inout [PlayEvent]) {
        winner = team
        events.append(.gameOver(winner: team))
    }
}
