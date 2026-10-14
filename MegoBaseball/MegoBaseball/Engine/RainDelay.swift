import Foundation

/// The state of a rain delay in a 2-phone game, from this phone's point of view.
///
/// A delay starts when either player gets a phone call (or the link drops). Once nobody
/// is on a call and the phones are connected again, both get a 60-second window to tap
/// RESUME. Both tap: play resumes. One taps: the other forfeits. Neither: the game is
/// cancelled with no result.
struct RainDelay: Equatable {
    static let resumeWindow: TimeInterval = 60

    enum Verdict: Equatable {
        /// Still waiting on a call, the connection, or the resume window.
        case waiting
        /// Both players tapped RESUME.
        case resume
        /// The window closed and only the other player had tapped RESUME.
        case youForfeit
        /// The window closed and only this player had tapped RESUME.
        case opponentForfeits
        /// The window closed and neither player tapped RESUME.
        case cancelled
    }

    var meOnCall = false
    var themOnCall = false
    var connected = true
    /// When the resume window closes; nil until it opens.
    private(set) var resumeDeadline: Date?
    var meReady = false
    var themReady = false

    var anyoneOnCall: Bool { meOnCall || themOnCall }
    var windowOpen: Bool { resumeDeadline != nil }
    /// The host opens the resume window once nobody is on a call and the phones are connected.
    var readyToOpenWindow: Bool { !windowOpen && !anyoneOnCall && connected }

    mutating func openWindow(now: Date) {
        resumeDeadline = now.addingTimeInterval(Self.resumeWindow)
        meReady = false
        themReady = false
    }

    /// Another call started, so the countdown is off until it ends.
    mutating func closeWindow() {
        resumeDeadline = nil
        meReady = false
        themReady = false
    }

    func secondsLeft(now: Date) -> Int {
        guard let resumeDeadline else { return Int(Self.resumeWindow) }
        return max(0, Int(resumeDeadline.timeIntervalSince(now).rounded(.up)))
    }

    func verdict(now: Date) -> Verdict {
        guard let resumeDeadline else { return .waiting }
        if meReady && themReady { return .resume }
        guard now >= resumeDeadline else { return .waiting }
        switch (meReady, themReady) {
        case (true, false): return .opponentForfeits
        case (false, true): return .youForfeit
        default: return .cancelled
        }
    }
}
