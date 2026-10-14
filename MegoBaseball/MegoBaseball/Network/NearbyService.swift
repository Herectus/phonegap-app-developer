import MultipeerConnectivity
import UIKit

/// Finds and connects to one other phone running the game nearby, using Apple's
/// Multipeer Connectivity (Wi-Fi, peer-to-peer Wi-Fi or Bluetooth; no internet needed).
@MainActor
final class NearbyService: NSObject, ObservableObject {
    enum Role {
        case host
        case guest
    }

    enum Status: Equatable {
        case idle
        /// Host: advertising and waiting for someone to join.
        case hosting
        /// Guest: looking for hosts.
        case browsing
        case connecting(String)
        case connected(String)
        /// Mid-game: the link dropped and we're looking for the same opponent again.
        case reconnecting
    }

    /// Must match the `NSBonjourServices` entries in the Info.plist.
    static let serviceType = "mego-baseball"

    @Published private(set) var status: Status = .idle
    /// Hosts the guest can see, newest last.
    @Published private(set) var foundHosts: [MCPeerID] = []
    private(set) var role: Role?

    var onConnected: (@MainActor () -> Void)?
    var onDisconnected: (@MainActor () -> Void)?
    var onMessage: (@MainActor (NetMessage) -> Void)?

    private var myPeer: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    /// Bumped by `stop()` so a delayed `stop(after:)` can't cut off a newer connection.
    private var generation = 0
    /// This player's permanent ID, advertised so a dropped opponent can find us again.
    private var playerID = ""
    /// While reconnecting: the only player we'll connect to.
    private var expectedOpponentID: String?

    override init() {
        myPeer = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    /// Starts a fresh session advertised under the player's chosen name.
    private func prepare(name: String) {
        stop()
        if myPeer.displayName != name {
            session.delegate = nil
            myPeer = MCPeerID(displayName: name)
            session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
            session.delegate = self
        }
    }

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    func host(name: String, playerID: String) {
        prepare(name: name)
        self.playerID = playerID
        expectedOpponentID = nil
        role = .host
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeer, discoveryInfo: ["id": playerID],
                                                   serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        status = .hosting
    }

    func browse(name: String, playerID: String) {
        prepare(name: name)
        self.playerID = playerID
        expectedOpponentID = nil
        role = .guest
        foundHosts = []
        let browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        status = .browsing
    }

    func join(_ host: MCPeerID) {
        guard role == .guest, let browser else { return }
        status = .connecting(host.displayName)
        browser.invitePeer(host, to: session, withContext: Data(playerID.utf8), timeout: 20)
    }

    /// After a mid-game drop: host again or look again, but only for the same opponent,
    /// and connect to them automatically.
    func reconnect(as role: Role, name: String, playerID: String, opponentID: String) {
        switch role {
        case .host: host(name: name, playerID: playerID)
        case .guest: browse(name: name, playerID: playerID)
        }
        expectedOpponentID = opponentID
        status = .reconnecting
    }

    /// Guest side: an invitation failed while reconnecting, so search again shortly.
    private func retryReconnecting() {
        guard role == .guest, let opponentID = expectedOpponentID else { return }
        let expected = generation
        let name = myPeer.displayName
        let id = playerID
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, self.generation == expected, self.status == .reconnecting else { return }
            self.reconnect(as: .guest, name: name, playerID: id, opponentID: opponentID)
        }
    }

    /// Disconnects after a short delay, so a last message (like a forfeit) can go out first.
    func stop(after seconds: Double) {
        let expected = generation
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.generation == expected else { return }
            self.stop()
        }
    }

    /// Stops looking, drops any connection and returns to idle.
    func stop() {
        generation += 1
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        foundHosts = []
        role = nil
        status = .idle
    }

    func send(_ message: NetMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? message.encoded() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: - Events, always handled on the main actor

    private func peer(_ peer: MCPeerID, changedTo state: MCSessionState) {
        switch state {
        case .connected:
            // One opponent is enough; stop being discoverable.
            advertiser?.stopAdvertisingPeer()
            browser?.stopBrowsingForPeers()
            status = .connected(peer.displayName)
            onConnected?()
        case .connecting:
            status = .connecting(peer.displayName)
        case .notConnected:
            let wasConnected = isConnected
            if wasConnected {
                stop()
                onDisconnected?()
            } else if expectedOpponentID != nil {
                status = .reconnecting
                retryReconnecting()
            } else if role == .guest {
                status = .browsing // invitation declined or timed out; keep looking
            } else if role == .host {
                status = .hosting
            }
        @unknown default:
            break
        }
    }

    private func received(_ data: Data) {
        guard let message = try? NetMessage.decode(data) else { return }
        onMessage?(message)
    }

    private func invitation(from peer: MCPeerID, context: Data?, reply: @escaping (Bool, MCSession?) -> Void) {
        // Accept the first player who asks while we're waiting; turn down anyone else.
        // While reconnecting, only the opponent from the interrupted game may join.
        let waiting = status == .hosting || status == .reconnecting
        let senderID = context.flatMap { String(data: $0, encoding: .utf8) }
        let allowed = expectedOpponentID == nil || senderID == expectedOpponentID
        let accept = waiting && allowed && session.connectedPeers.isEmpty
        if accept { status = .connecting(peer.displayName) }
        reply(accept, accept ? session : nil)
    }

    private func found(_ peer: MCPeerID, info: [String: String]?) {
        if status == .reconnecting {
            if let expected = expectedOpponentID, info?["id"] == expected { join(peer) }
            return
        }
        guard !foundHosts.contains(peer) else { return }
        foundHosts.append(peer)
    }

    private func lost(_ peer: MCPeerID) {
        foundHosts.removeAll { $0 == peer }
    }
}

// MultipeerConnectivity calls these on its own queues; hop to the main actor.

extension NearbyService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in self.peer(peerID, changedTo: state) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.received(data) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in self.invitation(from: peerID, context: context, reply: invitationHandler) }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in self.stop() }
    }
}

extension NearbyService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in self.found(peerID, info: info) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.lost(peerID) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in self.stop() }
    }
}
