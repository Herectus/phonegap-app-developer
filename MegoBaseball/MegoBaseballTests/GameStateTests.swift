import XCTest
@testable import MegoBaseball

/// Always returns the same value, so `Double.random(in: 0..<1)` is 0 for `.low` and ~1 for `.high`.
private struct FixedRNG: RandomNumberGenerator {
    static let low = FixedRNG(value: 0)
    static let high = FixedRNG(value: .max)
    let value: UInt64
    mutating func next() -> UInt64 { value }
}

final class GameStateTests: XCTestCase {
    private var rng = FixedRNG.high

    private func state(bases: [Bool] = [false, false, false], outs: Int = 0) -> GameState {
        var game = GameState(innings: 9)
        game.bases = bases
        game.outs = outs
        return game
    }

    func testWalkWithBasesLoadedForcesInARun() {
        var game = state(bases: [true, true, true])
        game.balls = 3
        let events = game.apply(.take(strike: false), rng: &rng)
        XCTAssertEqual(events, [.walk, .runsScored(1)])
        XCTAssertEqual(game.bases, [true, true, true])
        XCTAssertEqual(game.score(of: .visitor), 1)
        XCTAssertEqual(game.balls, 0)
    }

    func testWalkOnlyMovesForcedRunners() {
        var game = state(bases: [false, false, true])
        game.balls = 3
        game.apply(.take(strike: false), rng: &rng)
        XCTAssertEqual(game.bases, [true, false, true])
        XCTAssertEqual(game.score(of: .visitor), 0)
    }

    func testHomeRunClearsTheBases() {
        var game = state(bases: [true, false, true])
        let events = game.apply(.contact(.hit(.homeRun, .homeRun)), rng: &rng)
        XCTAssertEqual(events, [.hit(.homeRun, .homeRun), .runsScored(3)])
        XCTAssertEqual(game.bases, [false, false, false])
        XCTAssertEqual(game.score(of: .visitor), 3)
    }

    func testDoubleAdvancesRunnersTwoBases() {
        var game = state(bases: [true, false, false])
        game.apply(.contact(.hit(.double, .double)), rng: &rng)
        XCTAssertEqual(game.bases, [false, true, true])
        XCTAssertEqual(game.score(of: .visitor), 0)
    }

    func testFoulWithTwoStrikesDoesNotStrikeOut() {
        var game = state()
        game.strikes = 2
        game.apply(.contact(.foul(.foulLeft)), rng: &rng)
        XCTAssertEqual(game.strikes, 2)
        XCTAssertEqual(game.outs, 0)
    }

    func testThreeStrikeoutsRetireTheSide() {
        var game = state()
        for _ in 0..<9 { game.apply(.swingAndMiss, rng: &rng) }
        XCTAssertEqual(game.half, .bottom)
        XCTAssertEqual(game.inning, 1)
        XCTAssertEqual(game.outs, 0)
    }

    func testSacrificeFlyScoresRunnerFromThird() {
        var game = state(bases: [false, false, true])
        let events = game.apply(.contact(.flyOut(.centerField)), rng: &rng)
        XCTAssertEqual(events, [.out(.centerField, fly: true), .sacrificeFly, .runsScored(1)])
        XCTAssertEqual(game.outs, 1)
        XCTAssertEqual(game.bases, [false, false, false])
    }

    func testNoSacrificeFlyOnThirdOut() {
        var game = state(bases: [false, false, true], outs: 2)
        game.apply(.contact(.flyOut(.leftField)), rng: &rng)
        XCTAssertEqual(game.score(of: .visitor), 0)
        XCTAssertEqual(game.half, .bottom)
    }

    func testGroundBallDoublePlay() {
        var game = state(bases: [true, false, false])
        var low = FixedRNG.low
        let events = game.apply(.contact(.groundOut(.shortstop)), rng: &low)
        XCTAssertEqual(events, [.doublePlay(.shortstop)])
        XCTAssertEqual(game.outs, 2)
        XCTAssertEqual(game.bases, [false, false, false])
    }

    func testGroundOutWithoutDoublePlayMovesRunnersUp() {
        var game = state(bases: [true, false, true])
        let events = game.apply(.contact(.groundOut(.secondBase)), rng: &rng)
        XCTAssertEqual(events, [.out(.secondBase, fly: false), .runsScored(1)])
        XCTAssertEqual(game.bases, [false, true, false])
        XCTAssertEqual(game.outs, 1)
    }

    func testWalkOffHomeRunEndsTheGame() {
        var game = state()
        game.inning = 9
        game.half = .bottom
        game.score = [2, 2]
        let events = game.apply(.contact(.hit(.homeRun, .homeRun)), rng: &rng)
        XCTAssertEqual(events.last, .gameOver(winner: .home))
        XCTAssertEqual(game.winner, .home)
    }

    func testHomeTeamLeadingAfterTopOfNinthWins() {
        var game = state(outs: 2)
        game.inning = 9
        game.score = [1, 3]
        game.strikes = 2
        let events = game.apply(.swingAndMiss, rng: &rng)
        XCTAssertEqual(events, [.strikeout, .sideRetired, .gameOver(winner: .home)])
    }

    func testTieAfterNineGoesToExtraInnings() {
        var game = state(outs: 2)
        game.inning = 9
        game.half = .bottom
        game.score = [4, 4]
        game.strikes = 2
        game.apply(.swingAndMiss, rng: &rng)
        XCTAssertNil(game.winner)
        XCTAssertEqual(game.inning, 10)
        XCTAssertEqual(game.half, .top)
    }

    func testVisitorWinsWhenHomeTrailsAfterBottomOfNinth() {
        var game = state(outs: 2)
        game.inning = 9
        game.half = .bottom
        game.score = [5, 2]
        game.strikes = 2
        game.apply(.swingAndMiss, rng: &rng)
        XCTAssertEqual(game.winner, .visitor)
    }

    func testStealPrefersSecondOverHome() {
        let game = state(bases: [true, false, true])
        XCTAssertEqual(game.stealingRunnerBase, 0)
    }

    func testSuccessfulStealMovesRunner() {
        var game = state(bases: [true, false, false])
        XCTAssertEqual(game.resolveSteal(success: true), [.stolenBase(to: 1)])
        XCTAssertEqual(game.bases, [false, true, false])
    }

    func testStealOfHomeScores() {
        var game = state(bases: [false, false, true])
        XCTAssertEqual(game.resolveSteal(success: true), [.stolenBase(to: 3), .runsScored(1)])
        XCTAssertEqual(game.score(of: .visitor), 1)
    }

    func testCaughtStealingCanEndTheInning() {
        var game = state(bases: [true, false, false], outs: 2)
        XCTAssertEqual(game.resolveSteal(success: false), [.caughtStealing, .sideRetired])
        XCTAssertEqual(game.half, .bottom)
    }
}

final class RulesTests: XCTestCase {
    func testSwingTimingWindows() {
        XCTAssertEqual(SwingTiming.classify(delta: 0.0), .perfect)
        XCTAssertEqual(SwingTiming.classify(delta: -0.03), .perfect)
        XCTAssertEqual(SwingTiming.classify(delta: 0.06), .good)
        XCTAssertEqual(SwingTiming.classify(delta: -0.1), .fair(early: true))
        XCTAssertEqual(SwingTiming.classify(delta: 0.1), .fair(early: false))
        XCTAssertEqual(SwingTiming.classify(delta: 0.2), .miss)
        XCTAssertEqual(SwingTiming.classify(delta: -0.5), .miss)
    }

    func testBadTimingIsASwingAndMiss() {
        var rng = SystemRandomNumberGenerator()
        XCTAssertEqual(Rules.outcome(swingDelta: 0.3, pitch: .fastball, rng: &rng), .swingAndMiss)
    }

    func testPerfectTimingAlwaysPutsTheBallInPlay() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let outcome = Rules.outcome(swingDelta: 0.01, pitch: .curve, rng: &rng)
            guard case .contact(let ball) = outcome else { return XCTFail("expected contact, got \(outcome)") }
            if case .foul = ball { XCTFail("perfect swing should never foul") }
            if case .groundOut = ball { XCTFail("perfect swing should never ground out") }
        }
    }

    func testTakenPitchIsBallOrStrike() {
        var low = FixedRNG.low
        XCTAssertEqual(Rules.outcome(swingDelta: nil, pitch: .fastball, rng: &low), .take(strike: true))
        var high = FixedRNG.high
        XCTAssertEqual(Rules.outcome(swingDelta: nil, pitch: .fastball, rng: &high), .take(strike: false))
    }

    func testEveryPitchReachesThePlate() {
        for pitch in PitchType.allCases {
            XCTAssertEqual(pitch.baseIntervals.count, PitchType.trackLength)
        }
    }
}

final class NetMessageTests: XCTestCase {
    func testMessagesSurviveTheTripBetweenPhones() throws {
        var state = GameState(innings: 6)
        state.bases = [true, false, true]
        state.score = [3, 1]
        state.half = .bottom
        let messages: [NetMessage] = [
            .hello(playerID: "ABC-123", name: "SAM"),
            .forfeit,
            .rainDelay(onCall: true),
            .resumeWindow,
            .readyToResume,
            .resumeGame(state: state),
            .start(innings: 9),
            .newGameRequest,
            .pitchRequest(.curve),
            .pitch(.fastball, intervals: [0.06, 0.07], serial: 4),
            .stealStarted(serial: 4),
            .batterReport(serial: 4, swingDelta: nil, steal: true),
            .batterReport(serial: 5, swingDelta: -0.02, steal: false),
            .result(serial: 5,
                     events: [.hit(.double, .double), .runsScored(1), .out(.leftField, fly: true),
                              .stolenBase(to: 2), .gameOver(winner: .home)],
                     basesBefore: [true, false, false], swung: true, state: state),
        ]
        for message in messages {
            XCTAssertEqual(try NetMessage.decode(message.encoded()), message)
        }
    }
}

final class RecordTableTests: XCTestCase {
    private let sam = Opponent(id: "sam-id", name: "SAM")
    private let alex = Opponent(id: "alex-id", name: "ALEX")

    func testWinsAndLossesAreKeptPerOpponent() {
        var table = RecordTable()
        table.record(won: true, against: sam)
        table.record(won: false, against: sam)
        table.record(won: true, against: sam)
        table.record(won: false, against: alex)
        XCTAssertEqual(table.record(against: sam)?.summary, "2-1")
        XCTAssertEqual(table.record(against: alex)?.summary, "0-1")
    }

    func testForfeitsCountAsWinsAndLossesAndAreTalliedSeparately() {
        var table = RecordTable()
        table.record(won: true, forfeit: true, against: sam)
        table.record(won: false, forfeit: true, against: sam)
        let entry = table.record(against: sam)
        XCTAssertEqual(entry?.summary, "1-1")
        XCTAssertEqual(entry?.forfeitWins, 1)
        XCTAssertEqual(entry?.forfeitLosses, 1)
    }

    func testRenamedOpponentKeepsTheirRecord() {
        var table = RecordTable()
        table.record(won: true, against: sam)
        table.record(won: true, against: Opponent(id: "sam-id", name: "SAMMY"))
        XCTAssertEqual(table.all.count, 1)
        XCTAssertEqual(table.all.first?.name, "SAMMY")
        XCTAssertEqual(table.all.first?.wins, 2)
    }

    func testMostRecentOpponentListedFirst() {
        var table = RecordTable()
        table.record(won: true, against: sam, on: Date(timeIntervalSince1970: 100))
        table.record(won: true, against: alex, on: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(table.all.map(\.name), ["ALEX", "SAM"])
    }

    func testTableSurvivesSaving() throws {
        var table = RecordTable()
        table.record(won: true, forfeit: true, against: sam)
        let data = try JSONEncoder().encode(table)
        XCTAssertEqual(try JSONDecoder().decode(RecordTable.self, from: data), table)
    }
}

final class RainDelayTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    private func openDelay() -> RainDelay {
        var delay = RainDelay()
        delay.openWindow(now: start)
        return delay
    }

    func testNoWindowWhileAnyoneIsOnACallOrDisconnected() {
        var delay = RainDelay()
        delay.themOnCall = true
        XCTAssertFalse(delay.readyToOpenWindow)
        delay.themOnCall = false
        delay.connected = false
        XCTAssertFalse(delay.readyToOpenWindow)
        delay.connected = true
        XCTAssertTrue(delay.readyToOpenWindow)
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(1_000)), .waiting)
    }

    func testBothReadyResumesRightAway() {
        var delay = openDelay()
        delay.meReady = true
        delay.themReady = true
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(5)), .resume)
    }

    func testOnlyOnePlayerReadyWaitsUntilTheDeadline() {
        var delay = openDelay()
        delay.meReady = true
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(59)), .waiting)
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(60)), .opponentForfeits)
    }

    func testPlayerWhoIgnoresTheWindowForfeits() {
        var delay = openDelay()
        delay.themReady = true
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(61)), .youForfeit)
    }

    func testNeitherReadyCancelsTheGame() {
        let delay = openDelay()
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(61)), .cancelled)
    }

    func testNewCallClosesTheWindowAndClearsReady() {
        var delay = openDelay()
        delay.meReady = true
        delay.themOnCall = true
        delay.closeWindow()
        XCTAssertFalse(delay.windowOpen)
        XCTAssertFalse(delay.meReady)
        XCTAssertEqual(delay.verdict(now: start.addingTimeInterval(500)), .waiting)
    }

    func testCountdown() {
        let delay = openDelay()
        XCTAssertEqual(delay.secondsLeft(now: start), 60)
        XCTAssertEqual(delay.secondsLeft(now: start.addingTimeInterval(59.2)), 1)
        XCTAssertEqual(delay.secondsLeft(now: start.addingTimeInterval(90)), 0)
    }
}
