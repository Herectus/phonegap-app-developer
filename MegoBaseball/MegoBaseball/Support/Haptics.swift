import UIKit

/// Thin wrapper over UIKit's feedback generators.
@MainActor
final class Haptics {
    enum Kind {
        case tap, contact, bigHit, out, success, warning
    }

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    func play(_ kind: Kind) {
        switch kind {
        case .tap: light.impactOccurred()
        case .contact: medium.impactOccurred()
        case .bigHit: heavy.impactOccurred()
        case .out: rigid.impactOccurred()
        case .success: notification.notificationOccurred(.success)
        case .warning: notification.notificationOccurred(.warning)
        }
    }
}
