import Foundation

/// Turns a pitch and the batter's swing timing into a result on the field.
enum Rules {
    private enum Contact {
        case single, double, triple, homeRun, flyOut, groundOut, foul
    }

    /// `swingDelta` is nil when the batter took the pitch.
    static func outcome<R: RandomNumberGenerator>(
        swingDelta: Double?,
        pitch: PitchType,
        rng: inout R
    ) -> PitchOutcome {
        guard let delta = swingDelta else {
            let strike = Double.random(in: 0..<1, using: &rng) < pitch.calledStrikeChance
            return .take(strike: strike)
        }

        let early = delta < 0
        let table: [(Contact, Double)]
        switch SwingTiming.classify(delta: delta) {
        case .miss:
            return .swingAndMiss
        case .perfect:
            table = [
                (.homeRun, pitch == .fastball ? 36 : 30),
                (.triple, 10),
                (.double, 25),
                (.single, 25),
                (.flyOut, 10),
            ]
        case .good:
            table = [
                (.homeRun, pitch == .fastball ? 10 : 6),
                (.triple, 4),
                (.double, 14),
                (.single, 36),
                (.flyOut, 20),
                (.groundOut, 15),
                (.foul, 5),
            ]
        case .fair:
            table = [
                (.single, 10),
                (.flyOut, 10),
                (.groundOut, 30),
                (.foul, 50),
            ]
        }

        let contact = pick(table, rng: &rng)
        return .contact(battedBall(for: contact, early: early, rng: &rng))
    }

    /// Early swings pull the ball to left field, late swings go the other way.
    private static func battedBall<R: RandomNumberGenerator>(
        for contact: Contact,
        early: Bool,
        rng: inout R
    ) -> BattedBall {
        switch contact {
        case .single: return .hit(.single, early ? .singleLeft : .singleRight)
        case .double: return .hit(.double, .double)
        case .triple: return .hit(.triple, .triple)
        case .homeRun: return .hit(.homeRun, .homeRun)
        case .flyOut: return .flyOut(FieldSpot.outfielders.randomElement(using: &rng)!)
        case .groundOut: return .groundOut(FieldSpot.infielders.randomElement(using: &rng)!)
        case .foul: return .foul(early ? .foulLeft : .foulRight)
        }
    }

    private static func pick<T, R: RandomNumberGenerator>(_ table: [(T, Double)], rng: inout R) -> T {
        let total = table.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (value, weight) in table {
            if roll < weight { return value }
            roll -= weight
        }
        return table[table.count - 1].0
    }
}
