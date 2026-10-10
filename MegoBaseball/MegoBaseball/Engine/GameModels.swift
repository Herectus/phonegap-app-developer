import Foundation

/// The two sides of the game. Visitors bat in the top half of each inning.
enum Team: Int, CaseIterable {
    case visitor = 0
    case home = 1

    var name: String { self == .visitor ? "VISITOR" : "HOME" }
    var opponent: Team { self == .visitor ? .home : .visitor }
}

enum Half: Equatable {
    case top
    case bottom
}

/// The three pitches the pitcher's buttons can throw.
enum PitchType: String, CaseIterable, Identifiable {
    case fastball
    case changeUp
    case curve

    var id: String { rawValue }

    /// Number of LEDs on the pitch track, mound side first. The last one sits on home plate.
    static let trackLength = 8

    var label: String {
        switch self {
        case .fastball: return "FAST"
        case .changeUp: return "CHANGE"
        case .curve: return "CURVE"
        }
    }

    /// Seconds between consecutive LEDs. `trackLength - 1` steps reach the plate,
    /// and one more step carries the ball past the batter into the catcher's mitt.
    var baseIntervals: [Double] {
        switch self {
        case .fastball:
            return Array(repeating: 0.065, count: PitchType.trackLength)
        case .changeUp:
            return Array(repeating: 0.12, count: PitchType.trackLength)
        case .curve:
            // Hangs early, then breaks hard toward the plate.
            return [0.13, 0.12, 0.10, 0.085, 0.07, 0.06, 0.05, 0.05]
        }
    }

    /// Chance that a pitch the batter takes is called a strike.
    var calledStrikeChance: Double {
        switch self {
        case .fastball: return 0.60
        case .changeUp: return 0.55
        case .curve: return 0.45
        }
    }

    /// Chance a runner stealing on this pitch beats the throw to second.
    var stealSuccessChance: Double {
        switch self {
        case .fastball: return 0.55
        case .changeUp: return 0.80
        case .curve: return 0.70
        }
    }
}

/// Every LED hole on the field that can light up when the ball is put in play.
enum FieldSpot: String, CaseIterable, Identifiable {
    case homeRun
    case singleLeft
    case singleRight
    case triple
    case double
    case foulLeft
    case foulRight
    case leftField
    case centerField
    case rightField
    case shortstop
    case secondBase
    case thirdBase
    case firstBase
    case pitcher

    var id: String { rawValue }

    var label: String {
        switch self {
        case .homeRun: return "HR"
        case .singleLeft, .singleRight: return "SINGLE"
        case .triple: return "TRIPLE"
        case .double: return "DOUBLE"
        case .foulLeft, .foulRight: return "FOUL"
        case .leftField: return "LF"
        case .centerField: return "CF"
        case .rightField: return "RF"
        case .shortstop: return "SS"
        case .secondBase: return "2B"
        case .thirdBase: return "3B"
        case .firstBase: return "1B"
        case .pitcher: return "P"
        }
    }

    static let outfielders: [FieldSpot] = [.leftField, .centerField, .rightField]
    static let infielders: [FieldSpot] = [.shortstop, .secondBase, .thirdBase, .firstBase, .pitcher]
}

enum HitKind: Int, Equatable {
    case single = 1
    case double = 2
    case triple = 3
    case homeRun = 4

    var bases: Int { rawValue }

    var label: String {
        switch self {
        case .single: return "SINGLE"
        case .double: return "DOUBLE"
        case .triple: return "TRIPLE"
        case .homeRun: return "HOME RUN"
        }
    }
}

enum BattedBall: Equatable {
    case hit(HitKind, FieldSpot)
    case flyOut(FieldSpot)
    case groundOut(FieldSpot)
    case foul(FieldSpot)
}

/// What happened on a single pitch, before the rules apply it to the game.
enum PitchOutcome: Equatable {
    case take(strike: Bool)
    case swingAndMiss
    case contact(BattedBall)
}

/// How well a swing lined up with the ball reaching the plate.
enum SwingTiming: Equatable {
    case perfect
    case good
    case fair(early: Bool)
    case miss

    static let perfectWindow = 0.035
    static let goodWindow = 0.08
    /// Swings further than this from the ball's arrival miss entirely.
    /// It is also how long after arrival a pitch is judged as taken.
    static let missWindow = 0.14

    /// `delta` is swing time minus the ball's arrival at the plate, in seconds.
    static func classify(delta: Double) -> SwingTiming {
        let error = abs(delta)
        if error <= perfectWindow { return .perfect }
        if error <= goodWindow { return .good }
        if error <= missWindow { return .fair(early: delta < 0) }
        return .miss
    }
}

/// Things the game announces after a pitch, in the order they happened.
enum PlayEvent: Equatable {
    case ball
    case calledStrike
    case swingingStrike
    case foul(FieldSpot)
    case walk
    case strikeout
    case hit(HitKind, FieldSpot)
    case out(FieldSpot, fly: Bool)
    case doublePlay(FieldSpot)
    case sacrificeFly
    case runsScored(Int)
    /// `to` is the base reached: 1 = second, 2 = third, 3 = home.
    case stolenBase(to: Int)
    case caughtStealing
    case sideRetired
    case gameOver(winner: Team)
}
