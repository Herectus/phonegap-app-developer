import Foundation

/// Who is on the other phone. `id` is that player's install ID, so a renamed player
/// keeps their record.
struct Opponent: Codable, Equatable {
    let id: String
    let name: String
}

/// This phone's wins and losses against one opponent.
struct HeadToHead: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var wins = 0
    var losses = 0
    var forfeitWins = 0
    var forfeitLosses = 0
    var lastPlayed = Date()

    var summary: String { "\(wins)-\(losses)" }
}

/// Every head-to-head record on this phone. Pure value type so it can be unit tested.
struct RecordTable: Codable, Equatable {
    private(set) var entries: [String: HeadToHead] = [:]

    /// Records a finished game. A forfeit also counts as a normal win or loss.
    mutating func record(won: Bool, forfeit: Bool = false, against opponent: Opponent, on date: Date = Date()) {
        var entry = entries[opponent.id] ?? HeadToHead(id: opponent.id, name: opponent.name)
        entry.name = opponent.name
        entry.lastPlayed = date
        if won {
            entry.wins += 1
            if forfeit { entry.forfeitWins += 1 }
        } else {
            entry.losses += 1
            if forfeit { entry.forfeitLosses += 1 }
        }
        entries[opponent.id] = entry
    }

    func record(against opponent: Opponent) -> HeadToHead? { entries[opponent.id] }

    /// Most recently played first.
    var all: [HeadToHead] { entries.values.sorted { $0.lastPlayed > $1.lastPlayed } }
}

/// Saves the record table in UserDefaults and publishes changes to the UI.
@MainActor
final class RecordBook: ObservableObject {
    @Published private(set) var table: RecordTable

    private let defaults: UserDefaults
    private static let key = "headToHeadRecords"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(RecordTable.self, from: data) {
            table = saved
        } else {
            table = RecordTable()
        }
    }

    func record(won: Bool, forfeit: Bool, against opponent: Opponent) {
        table.record(won: won, forfeit: forfeit, against: opponent)
        save()
    }

    func clear() {
        table = RecordTable()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(table) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
