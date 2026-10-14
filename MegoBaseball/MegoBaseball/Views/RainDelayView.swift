import SwiftUI

/// Shown in place of the buttons while a 2-phone game is in a rain delay.
struct RainDelayView: View {
    @Environment(\.uiScale) private var scale
    @EnvironmentObject private var game: GameController
    let delay: RainDelay

    init(delay: RainDelay) {
        self.delay = delay
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cloud.rain.fill")
                Text("RAIN DELAY")
            }
            .font(Theme.ledFont(22 * scale))
            .foregroundColor(Theme.ledOn)
            .shadow(color: Theme.ledOn.opacity(0.6), radius: 6)

            if delay.windowOpen {
                // Re-render every second so the countdown ticks.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("GAME RESUMES · 0:\(String(format: "%02d", delay.secondsLeft(now: context.date)))")
                        .font(Theme.ledFont(16 * scale))
                        .foregroundColor(.white)
                }
                RetroButton(title: delay.meReady ? "READY ✓" : "RESUME", height: 60, enabled: !delay.meReady) {
                    game.readyToResume()
                }
                Text(statusLine)
                    .font(.system(size: 13 * scale, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            } else {
                Text(waitingLine)
                    .font(.system(size: 14 * scale, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !delay.connected {
                    Button("Call Off Game (No Result)") { game.callOffGame() }
                        .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.buttonOrange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.6)))
    }

    private var rival: String { game.opponent?.name ?? "YOUR RIVAL" }

    private var statusLine: String {
        switch (delay.meReady, delay.themReady) {
        case (true, true): return "Both ready. Here we go!"
        case (true, false): return "Waiting for \(rival). If they don't tap RESUME in time, they forfeit."
        case (false, true): return "\(rival) is ready. Tap RESUME or you forfeit."
        case (false, false): return "Both players must tap RESUME. Whoever doesn't, forfeits. If neither does, the game is cancelled."
        }
    }

    private var waitingLine: String {
        if delay.meOnCall { return "You're on a call. The game is paused until it ends." }
        if delay.themOnCall { return "\(rival) is on a call. The game will resume after it ends." }
        if !delay.connected {
            return "Lost the link to \(rival). Reconnecting automatically. Keep the app open."
        }
        return "Getting ready to resume…"
    }
}
