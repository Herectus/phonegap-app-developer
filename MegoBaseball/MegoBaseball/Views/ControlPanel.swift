import SwiftUI

/// Pitcher buttons on top, batter buttons below.
struct ControlPanel: View {
    @Environment(\.uiScale) private var scale
    @EnvironmentObject private var game: GameController

    var body: some View {
        VStack(spacing: 10) {
            section("PITCHER", active: game.isHumanPitching) {
                HStack(spacing: 10) {
                    ForEach(PitchType.allCases) { pitch in
                        RetroButton(title: pitch.label, enabled: game.canPitch) {
                            game.pitch(pitch)
                        }
                    }
                }
            }
            section("BATTER", active: game.isHumanBatting) {
                HStack(spacing: 10) {
                    RetroButton(title: "STEAL", enabled: game.canSteal) {
                        game.steal()
                    }
                    .frame(maxWidth: 110 * scale)
                    RetroButton(title: "SWING", height: 72, enabled: game.canSwing) {
                        game.swing()
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, active: Bool,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(active ? 0.9 : 0.35))
            content()
        }
    }
}

/// An orange handheld-style button that fires the moment it is touched,
/// not on release, so swing timing is accurate.
struct RetroButton: View {
    @Environment(\.uiScale) private var scale
    let title: String
    var height: CGFloat = 54
    let enabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(title: String, height: CGFloat = 54, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.height = height
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Text(title)
            .font(.system(size: 17 * scale, weight: .heavy, design: .rounded))
            .foregroundColor(Color.black.opacity(0.75))
            .frame(maxWidth: .infinity, minHeight: height * scale)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Theme.buttonOrange, Theme.buttonOrangeDark],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: isPressed ? 0 : 3, y: isPressed ? 0 : 3)
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .opacity(enabled ? 1 : 0.35)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        if enabled { action() }
                    }
                    .onEnded { _ in isPressed = false }
            )
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { action() } }
    }
}
