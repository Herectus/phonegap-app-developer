import SwiftUI

/// Runs a game in real time: pitch flight, swing timing, the computer opponent,
/// and the LED animations and sounds that follow each pitch.
@MainActor
final class GameController: ObservableObject {
    enum Phase: Equatable {
        case off
        /// Waiting for the pitcher to choose a pitch.
        case ready
        case windup
        case pitching
        /// Showing what just happened.
        case result
        case gameOver
    }

    /// What the scoreboard and field show. Trails `engine` while a play animates.
    @Published private(set) var board = GameState()
    @Published private(set) var phase: Phase = .off
    /// Lit LED on the pitch track, or nil when the ball isn't in flight.
    @Published private(set) var ballIndex: Int?
    @Published private(set) var litSpot: FieldSpot?
    /// Ball travelling from home plate to where it was hit, in unit field coordinates.
    @Published private(set) var battedBallPosition: CGPoint?
    @Published private(set) var message = ""
    @Published private(set) var stealAttempted = false
    /// Teams controlled by people for the current game.
    @Published private(set) var humanTeams: Set<Team> = [.visitor]

    let settings: GameSettings
    private var engine = GameState()
    private let sound = SoundEngine()
    private let haptics = Haptics()
    private var rng = SystemRandomNumberGenerator()

    private var currentPitch: PitchType?
    private var arrivalTime: TimeInterval = 0
    private var hasSwung = false
    /// Increments every pitch so a late timer from an earlier pitch can't act on this one.
    private var pitchSerial = 0
    private var tasks: [UUID: Task<Void, Never>] = [:]

    init(settings: GameSettings) {
        self.settings = settings
    }

    // MARK: - Who controls what

    var isHumanBatting: Bool { humanTeams.contains(board.battingTeam) }
    var isHumanPitching: Bool { humanTeams.contains(board.fieldingTeam) }
    var isTwoPlayer: Bool { humanTeams.count == 2 }

    var canPitch: Bool { phase == .ready && isHumanPitching }
    var canSwing: Bool { (phase == .windup || phase == .pitching) && isHumanBatting && !hasSwung }
    var canSteal: Bool {
        (phase == .windup || phase == .pitching) && isHumanBatting
            && !stealAttempted && engine.stealingRunnerBase != nil
    }

    /// Base the runner is stealing from, for blinking that LED.
    var stealingBase: Int? { stealAttempted ? engine.stealingRunnerBase : nil }

    func label(for team: Team) -> String {
        if isTwoPlayer { return team == .visitor ? "P1" : "P2" }
        return humanTeams.contains(team) ? "YOU" : "CPU"
    }

    // MARK: - Power and game flow

    func powerOn() { newGame() }

    func powerOff() {
        cancelTasks()
        phase = .off
        ballIndex = nil
        litSpot = nil
        battedBallPosition = nil
        message = ""
    }

    func newGame() {
        cancelTasks()
        humanTeams = settings.mode == .manual ? [.visitor, .home] : [.visitor]
        engine = GameState(innings: settings.innings)
        board = engine
        ballIndex = nil
        litSpot = nil
        battedBallPosition = nil
        stealAttempted = false
        phase = .result
        message = "PLAY BALL!"
        play(.gameStart)
        run { controller in
            try await controller.pause(1.4)
            controller.enterReady()
        }
    }

    private func enterReady() {
        phase = .ready
        ballIndex = nil
        litSpot = nil
        battedBallPosition = nil
        stealAttempted = false
        hasSwung = false
        currentPitch = nil

        if isTwoPlayer {
            let batter = board.battingTeam == .visitor ? "P1" : "P2"
            let pitcher = board.fieldingTeam == .visitor ? "P1" : "P2"
            message = "\(batter) BATS · \(pitcher) PITCHES"
        } else if isHumanPitching {
            message = "YOU PITCH · PICK A PITCH"
        } else {
            message = "YOU'RE UP · GET READY"
        }

        if !isHumanPitching {
            run { controller in
                try await controller.pause(Double.random(in: 1.0...2.0))
                guard controller.phase == .ready else { return }
                controller.throwPitch(controller.cpuPitchChoice())
            }
        }
    }

    // MARK: - Player input

    func pitch(_ type: PitchType) {
        guard canPitch else { return }
        haptic(.tap)
        throwPitch(type)
    }

    func swing() {
        guard isHumanBatting else { return }
        performSwing()
    }

    func steal() {
        guard canSteal else { return }
        haptic(.tap)
        attemptSteal()
    }

    // MARK: - The pitch

    private func throwPitch(_ type: PitchType) {
        phase = .windup
        currentPitch = type
        pitchSerial += 1
        hasSwung = false
        stealAttempted = false
        litSpot = nil
        // Only announce the pitch when the batter is the computer; a person at the plate must guess.
        message = isHumanPitching && !isHumanBatting ? type.label : "HERE'S THE PITCH"
        play(.windup)

        // A little speed variation so no two pitches can be timed from memory.
        let speed = Double.random(in: 0.92...1.08)
        let intervals = type.baseIntervals.map { $0 * speed }

        let serial = pitchSerial
        run { controller in
            try await controller.pause(0.35)
            guard controller.pitchSerial == serial else { return }
            controller.startFlight(type, intervals: intervals)
        }
    }

    private func startFlight(_ type: PitchType, intervals: [Double]) {
        guard phase == .windup else { return }
        phase = .pitching
        let start = now()
        arrivalTime = start + intervals.prefix(PitchType.trackLength - 1).reduce(0, +)
        ballIndex = 0
        play(.tick)

        if !isHumanBatting { scheduleCPUBatter(for: type) }

        let arrival = arrivalTime
        let serial = pitchSerial
        run { controller in
            var stepTime = start
            for index in 1...intervals.count {
                stepTime += intervals[index - 1]
                try await controller.pause(until: stepTime)
                guard controller.phase == .pitching, controller.pitchSerial == serial else { return }
                controller.ballIndex = index
                controller.play(.tick)
            }
            try await controller.pause(until: arrival + SwingTiming.missWindow)
            guard controller.phase == .pitching, controller.pitchSerial == serial else { return }
            controller.resolvePitch(swingDelta: nil)
        }
    }

    private func performSwing() {
        guard phase == .pitching, !hasSwung else { return }
        hasSwung = true
        resolvePitch(swingDelta: now() - arrivalTime)
    }

    private func attemptSteal() {
        guard phase == .windup || phase == .pitching, !stealAttempted,
              engine.stealingRunnerBase != nil else { return }
        stealAttempted = true
        message = "RUNNER GOING!"
        play(.steal)
    }

    private func resolvePitch(swingDelta: Double?) {
        guard phase == .pitching, let pitch = currentPitch else { return }
        phase = .result
        ballIndex = nil

        let outcome = Rules.outcome(swingDelta: swingDelta, pitch: pitch, rng: &rng)
        let basesBefore = engine.bases
        var events = engine.apply(outcome, rng: &rng)

        // A steal only matters when the ball wasn't put in play and the at-bat didn't end in a walk.
        let ballInPlay: Bool
        if case .contact = outcome { ballInPlay = true } else { ballInPlay = false }
        let stops = events.contains { event in
            switch event {
            case .walk, .sideRetired, .gameOver: return true
            default: return false
            }
        }
        if stealAttempted && !ballInPlay && !stops {
            let success = Double.random(in: 0..<1, using: &rng) < engine.stealChance(on: pitch)
            events += engine.resolveSteal(success: success)
        }

        let swung = swingDelta != nil
        let playEvents = events
        run { controller in
            try await controller.animate(playEvents, swung: swung, basesBefore: basesBefore)
        }
    }

    // MARK: - Computer opponent

    private func cpuPitchChoice() -> PitchType {
        let roll = Double.random(in: 0..<1)
        if roll < 0.45 { return .fastball }
        if roll < 0.70 { return .changeUp }
        return .curve
    }

    private func scheduleCPUBatter(for pitch: PitchType) {
        if engine.stealingRunnerBase == 0, !engine.bases[1], Double.random(in: 0..<1) < 0.15 {
            attemptSteal()
        }

        guard Double.random(in: 0..<1) < 0.72 else { return } // takes the pitch

        let base = settings.cpuSkill == .pro ? 0.055 : 0.095
        let spread: Double
        switch pitch {
        case .fastball: spread = base
        case .changeUp: spread = base * 0.85
        case .curve: spread = base * 1.25
        }
        let swingAt = arrivalTime + gaussian() * spread
        let serial = pitchSerial
        run { controller in
            try await controller.pause(until: swingAt)
            guard controller.pitchSerial == serial else { return }
            controller.performSwing()
        }
    }

    private func gaussian() -> Double {
        let u1 = Double.random(in: Double.ulpOfOne..<1)
        let u2 = Double.random(in: 0..<1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    // MARK: - Showing the result

    private func animate(_ events: [PlayEvent], swung: Bool, basesBefore: [Bool]) async throws {
        if swung { haptic(.tap) }

        for event in events {
            switch event {
            case .ball:
                board.balls = min(board.balls + 1, 3)
                show("BALL", .ball)
                try await pause(0.5)

            case .calledStrike:
                board.strikes = min(board.strikes + 1, 2)
                show("STRIKE", .strike)
                try await pause(0.5)

            case .swingingStrike:
                board.strikes = min(board.strikes + 1, 2)
                show("SWING & A MISS", .swingMiss)
                try await pause(0.6)

            case .foul(let spot):
                haptic(.contact)
                try await fly(to: spot)
                if board.strikes < 2 { board.strikes += 1 }
                show("FOUL BALL", .foul)
                try await blink(spot)

            case .walk:
                show("BALL FOUR · TAKE YOUR BASE", .walk)
                board.balls = 0
                board.strikes = 0
                board.bases = engine.bases
                try await pause(0.9)

            case .strikeout:
                show(swung ? "STRIKE THREE · SWINGING" : "STRIKE THREE · LOOKING", .out)
                haptic(.warning)
                board.balls = 0
                board.strikes = 0
                board.outs += 1
                try await pause(1.0)

            case .hit(let kind, let spot):
                haptic(kind == .homeRun ? .bigHit : .contact)
                try await fly(to: spot)
                switch kind {
                case .single: show("SINGLE!", .single)
                case .double, .triple: show("\(kind.label)!", .extraBase)
                case .homeRun: show("HOME RUN!!", .homeRun); haptic(.success)
                }
                board.balls = 0
                board.strikes = 0
                try await blink(spot)
                try await runBases(from: basesBefore, steps: kind.bases)

            case .out(let spot, let fly):
                haptic(.contact)
                try await self.fly(to: spot)
                show(fly ? "FLY OUT · \(spot.label)" : "GROUND OUT · \(spot.label)", .out)
                haptic(.out)
                board.balls = 0
                board.strikes = 0
                board.outs += 1
                try await blink(spot)

            case .doublePlay(let spot):
                haptic(.contact)
                try await fly(to: spot)
                show("DOUBLE PLAY!", .out)
                haptic(.out)
                board.balls = 0
                board.strikes = 0
                board.outs += 2
                board.bases[0] = false
                try await blink(spot)

            case .sacrificeFly:
                show("SAC FLY · RUNNER SCORES", .run)
                try await pause(0.8)

            case .runsScored(let runs):
                // Hits already counted their runs as the runners crossed the plate.
                let team = board.battingTeam.rawValue
                if board.score[team] < engine.score[team] {
                    board.score[team] = engine.score[team]
                    board.bases = engine.bases
                    play(.run)
                    if !events.contains(where: isHit) {
                        message = runs == 1 ? "RUN SCORES" : "\(runs) RUNS SCORE"
                    }
                    try await pause(0.6)
                }

            case .stolenBase(let to):
                show(to == 3 ? "STEALS HOME!" : "STOLEN BASE!", .safe)
                haptic(.success)
                board.bases = engine.bases
                try await pause(0.9)

            case .caughtStealing:
                show("CAUGHT STEALING", .out)
                haptic(.out)
                board.outs += 1
                board.bases = engine.bases
                try await pause(0.9)

            case .sideRetired:
                board.outs = 3
                show("3 OUTS · SIDE RETIRED", .sideRetired)
                try await pause(1.6)

            case .gameOver:
                break
            }
        }

        board = engine
        litSpot = nil

        if let winner = engine.winner {
            phase = .gameOver
            let high = max(engine.score[0], engine.score[1])
            let low = min(engine.score[0], engine.score[1])
            message = "GAME OVER · \(label(for: winner)) WIN \(high)-\(low)"
            play(.gameOver)
            haptic(.success)
        } else {
            try await pause(0.4)
            enterReady()
        }
    }

    private func isHit(_ event: PlayEvent) -> Bool {
        if case .hit = event { return true }
        return false
    }

    /// Moves a lit dot from home plate out to the spot the ball was hit.
    private func fly(to spot: FieldSpot) async throws {
        battedBallPosition = FieldLayout.home
        try await pause(0.02)
        withAnimation(.easeOut(duration: 0.4)) {
            battedBallPosition = FieldLayout.point(for: spot)
        }
        try await pause(0.4)
        battedBallPosition = nil
    }

    private func blink(_ spot: FieldSpot) async throws {
        for _ in 0..<3 {
            litSpot = spot
            try await pause(0.16)
            litSpot = nil
            try await pause(0.1)
        }
        litSpot = spot
        try await pause(0.4)
    }

    /// Steps every runner (and the batter) around the bases one base at a time.
    private func runBases(from start: [Bool], steps: Int) async throws {
        var bases = start
        let team = board.battingTeam.rawValue
        for step in 1...steps {
            // The batter joins the runners on the first step and moves with them after that.
            let scored = bases[2] ? 1 : 0
            bases = [step == 1, bases[0], bases[1]]
            board.bases = bases
            if scored > 0 {
                board.score[team] += scored
                play(.run)
            } else {
                play(.tick)
            }
            try await pause(0.22)
        }
    }

    // MARK: - Helpers

    private func show(_ text: String, _ effect: SoundEngine.Effect) {
        message = text
        play(effect)
    }

    private func play(_ effect: SoundEngine.Effect) {
        guard settings.soundOn else { return }
        sound.play(effect)
    }

    private func haptic(_ kind: Haptics.Kind) {
        guard settings.hapticsOn else { return }
        haptics.play(kind)
    }

    private func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Sleeps, throwing `CancellationError` if the game was reset or powered off meanwhile.
    private func pause(_ seconds: Double) async throws {
        guard seconds > 0 else {
            try Task.checkCancellation()
            return
        }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func pause(until time: TimeInterval) async throws {
        try await pause(time - now())
    }

    /// Starts a cancellable piece of game flow. `newGame` and `powerOff` cancel them all.
    private func run(_ body: @escaping @MainActor (GameController) async throws -> Void) {
        let id = UUID()
        tasks[id] = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await body(self)
            self.tasks[id] = nil
        }
    }

    private func cancelTasks() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
