import UIKit

/// Player preferences, saved between launches.
@MainActor
final class GameSettings: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        /// One player bats and pitches against the computer, like the AUTO switch.
        case auto = "AUTO"
        /// Two players pass the phone: one pitches while the other bats.
        case manual = "MANUAL"
        /// Two players, each on their own iPhone, connected over Wi-Fi/Bluetooth.
        case nearby = "NEARBY"

        var id: String { rawValue }
    }

    enum Skill: String, CaseIterable, Identifiable {
        case rookie = "ROOKIE"
        case pro = "PRO"

        var id: String { rawValue }
    }

    static let inningChoices = [3, 6, 9]

    @Published var mode: Mode { didSet { defaults.set(mode.rawValue, forKey: Keys.mode) } }
    @Published var innings: Int { didSet { defaults.set(innings, forKey: Keys.innings) } }
    @Published var cpuSkill: Skill { didSet { defaults.set(cpuSkill.rawValue, forKey: Keys.skill) } }
    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.sound) } }
    @Published var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.haptics) } }
    /// Name shown to the other phone in nearby games.
    @Published var playerName: String { didSet { defaults.set(playerName, forKey: Keys.playerName) } }
    /// Permanent ID for this install, so the other phone can keep a record against us.
    let playerID: String

    static let maxNameLength = 12

    /// The player name trimmed and shortened, with a fallback when it's blank.
    var displayName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "PLAYER" : String(trimmed.prefix(Self.maxNameLength)).uppercased()
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let mode = "mode"
        static let innings = "innings"
        static let skill = "cpuSkill"
        static let sound = "soundOn"
        static let haptics = "hapticsOn"
        static let playerName = "playerName"
        static let playerID = "playerID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.mode: Mode.auto.rawValue,
            Keys.innings: 9,
            Keys.skill: Skill.rookie.rawValue,
            Keys.sound: true,
            Keys.haptics: true,
        ])
        mode = Mode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .auto
        let savedInnings = defaults.integer(forKey: Keys.innings)
        innings = GameSettings.inningChoices.contains(savedInnings) ? savedInnings : 9
        cpuSkill = Skill(rawValue: defaults.string(forKey: Keys.skill) ?? "") ?? .rookie
        soundOn = defaults.bool(forKey: Keys.sound)
        hapticsOn = defaults.bool(forKey: Keys.haptics)
        playerName = defaults.string(forKey: Keys.playerName) ?? UIDevice.current.name
        if let saved = defaults.string(forKey: Keys.playerID) {
            playerID = saved
        } else {
            playerID = UUID().uuidString
            defaults.set(playerID, forKey: Keys.playerID)
        }
    }
}
