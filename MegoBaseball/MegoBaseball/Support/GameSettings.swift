import Foundation

/// Player preferences, saved between launches.
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

    private let defaults: UserDefaults

    private enum Keys {
        static let mode = "mode"
        static let innings = "innings"
        static let skill = "cpuSkill"
        static let sound = "soundOn"
        static let haptics = "hapticsOn"
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
    }
}
