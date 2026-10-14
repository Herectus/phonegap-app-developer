import SwiftUI
import MultipeerConnectivity

/// Host or join a game with another iPhone or iPad in the same room.
struct NearbyLobbyView: View {
    @Environment(\.uiScale) private var scale
    @EnvironmentObject private var game: GameController
    @ObservedObject var nearby: NearbyService

    init(nearby: NearbyService) {
        self.nearby = nearby
    }

    var body: some View {
        VStack(spacing: 14) {
            switch nearby.status {
            case .idle:
                NameField()
                HStack(spacing: 10) {
                    RetroButton(title: "HOST GAME", height: 64) { game.hostNearbyGame() }
                    RetroButton(title: "JOIN GAME", height: 64) { game.joinNearbyGame() }
                }
                hint("Both devices need Wi-Fi or Bluetooth turned on and must be in the same room. "
                     + "The host's innings setting is used.")

            case .hosting:
                status("WAITING FOR A PLAYER…", spinning: true)
                hint("On the other iPhone or iPad, choose 2P · 2 DEVICES and tap JOIN GAME.")
                cancelButton

            case .browsing:
                status(nearby.foundHosts.isEmpty ? "LOOKING FOR GAMES…" : "TAP A GAME TO JOIN",
                       spinning: nearby.foundHosts.isEmpty)
                ForEach(nearby.foundHosts, id: \.self) { host in
                    RetroButton(title: host.displayName.uppercased(), height: 54) { nearby.join(host) }
                }
                hint("Ask the other player to tap HOST GAME.")
                cancelButton

            case .connecting(let name):
                status("CONNECTING TO \(name.uppercased())…", spinning: true)
                cancelButton

            case .connected(let name):
                status("CONNECTED TO \(name.uppercased())", spinning: false)
                hint(nearby.role == .host ? "Starting the game…" : "Waiting for the host to start…")

            case .reconnecting:
                status("RECONNECTING…", spinning: true)
            }
        }
    }

    private var cancelButton: some View {
        Button("Cancel") { game.cancelNearby() }
            .font(.system(size: 15 * scale, weight: .bold, design: .rounded))
            .foregroundColor(Theme.buttonOrange)
    }

    private func status(_ text: String, spinning: Bool) -> some View {
        HStack(spacing: 8) {
            if spinning { ProgressView().tint(Theme.ledOn) }
            Text(text)
                .font(Theme.ledFont(15 * scale))
                .foregroundColor(Theme.ledOn)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13 * scale, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The name the other phone sees and keeps your record under.
private struct NameField: View {
    @Environment(\.uiScale) private var scale
    @EnvironmentObject private var settings: GameSettings

    var body: some View {
        HStack {
            Text("YOUR NAME")
                .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            TextField("Name", text: $settings.playerName)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .font(Theme.ledFont(16 * scale))
                .foregroundColor(Theme.ledOn)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black))
                .onChange(of: settings.playerName) {
                    if settings.playerName.count > GameSettings.maxNameLength {
                        settings.playerName = String(settings.playerName.prefix(GameSettings.maxNameLength))
                    }
                }
        }
    }
}

/// Wins and losses against everyone this phone has played nearby.
struct RecordsView: View {
    @Environment(\.uiScale) private var scale
    @ObservedObject var records: RecordBook
    @State private var confirmingClear = false

    init(records: RecordBook) {
        self.records = records
    }

    var body: some View {
        let all = records.table.all
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HEAD-TO-HEAD RECORDS")
                    .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if !all.isEmpty {
                    Button("Clear") { confirmingClear = true }
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.buttonOrange)
                }
            }

            if all.isEmpty {
                Text("No 2-device games yet.")
                    .font(.system(size: 13 * scale, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            ForEach(all) { entry in
                HStack {
                    Text(entry.name)
                        .foregroundColor(.white)
                    Spacer()
                    if entry.forfeitWins + entry.forfeitLosses > 0 {
                        Text("FF \(entry.forfeitWins)-\(entry.forfeitLosses)")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text("W \(entry.wins)  L \(entry.losses)")
                        .foregroundColor(Theme.ledOn)
                }
                .font(Theme.ledFont(14 * scale))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
        .confirmationDialog("Erase every head-to-head record on this device?",
                            isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Erase Records", role: .destructive) { records.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
