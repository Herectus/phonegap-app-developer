import SwiftUI
import MultipeerConnectivity

/// Host or join a game with another iPhone in the same room.
struct NearbyLobbyView: View {
    @EnvironmentObject private var game: GameController
    @ObservedObject var nearby: NearbyService

    var body: some View {
        VStack(spacing: 14) {
            switch nearby.status {
            case .idle:
                HStack(spacing: 10) {
                    RetroButton(title: "HOST GAME", height: 64) { game.hostNearbyGame() }
                    RetroButton(title: "JOIN GAME", height: 64) { game.joinNearbyGame() }
                }
                hint("Both phones need Wi-Fi or Bluetooth turned on and must be in the same room. "
                     + "The host's innings setting is used.")

            case .hosting:
                status("WAITING FOR A PLAYER…", spinning: true)
                hint("On the other iPhone, choose 2P · 2 PHONES and tap JOIN GAME.")
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
            }
        }
    }

    private var cancelButton: some View {
        Button("Cancel") { game.cancelNearby() }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(Theme.buttonOrange)
    }

    private func status(_ text: String, spinning: Bool) -> some View {
        HStack(spacing: 8) {
            if spinning { ProgressView().tint(Theme.ledOn) }
            Text(text)
                .font(Theme.ledFont(15))
                .foregroundColor(Theme.ledOn)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
