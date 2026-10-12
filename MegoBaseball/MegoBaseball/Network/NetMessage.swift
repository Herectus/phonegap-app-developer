import Foundation

/// Everything the two phones say to each other in a nearby game.
///
/// The host phone owns the official game state and the random rolls. The batter's
/// phone times the swing against its own copy of the pitch animation, so network lag
/// never decides whether a swing was early or late.
enum NetMessage: Codable, Equatable {
    /// Host → guest: start a new game. The host is the visitor, the guest is home.
    case start(innings: Int)
    /// Guest → host: the guest pressed NEW GAME.
    case newGameRequest
    /// Guest → host: the guest is pitching and chose this pitch.
    case pitchRequest(PitchType)
    /// Host → guest: a pitch is on its way. Both phones animate it with these intervals.
    case pitch(PitchType, intervals: [Double], serial: Int)
    /// Either way: the batter sent the runner.
    case stealStarted(serial: Int)
    /// Guest → host: the guest is batting; how their swing lined up (nil = took the pitch).
    case batterReport(serial: Int, swingDelta: Double?, steal: Bool)
    /// Host → guest: what happened, plus the game state afterwards.
    case result(serial: Int, events: [PlayEvent], basesBefore: [Bool], swung: Bool, state: GameState)

    func encoded() throws -> Data { try JSONEncoder().encode(self) }

    static func decode(_ data: Data) throws -> NetMessage {
        try JSONDecoder().decode(NetMessage.self, from: data)
    }
}
