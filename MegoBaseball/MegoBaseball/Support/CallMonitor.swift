import CallKit

/// Watches for phone calls (cellular, FaceTime and calling apps that use the iPhone call
/// screen) so a call can pause a 2-phone game as a rain delay instead of forfeiting it.
@MainActor
final class CallMonitor: NSObject {
    private let observer = CXCallObserver()
    /// Called with true when a call starts ringing or connects, false when the last one ends.
    var onChange: (@MainActor (Bool) -> Void)?

    override init() {
        super.init()
        observer.setDelegate(self, queue: .main)
    }

    /// True while any call is ringing, dialing or connected.
    var isOnCall: Bool { observer.calls.contains { !$0.hasEnded } }
}

extension CallMonitor: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        Task { @MainActor in self.onChange?(self.isOnCall) }
    }
}
