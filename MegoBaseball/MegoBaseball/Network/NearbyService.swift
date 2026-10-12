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

    private let myPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    override init() {
        myPeer = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    func host() {
        stop()
        role = .host
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeer, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        status = .hosting
    }

    func browse() {
        stop()
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
        browser.invitePeer(host, to: session, withContext: nil, timeout: 20)
    }

    /// Stops looking, drops any connection and returns to idle.
    func stop() {
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

    private func invitation(from peer: MCPeerID, reply: @escaping (Bool, MCSession?) -> Void) {
        // Accept the first player who asks while we're waiting; turn down anyone else.
        let accept = status == .hosting && session.connectedPeers.isEmpty
        if accept { status = .connecting(peer.displayName) }
        reply(accept, accept ? session : nil)
    }

    private func found(_ peer: MCPeerID) {
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
        Task { @MainActor in self.invitation(from: peerID, reply: invitationHandler) }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in self.stop() }
    }
}

extension NearbyService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in self.found(peerID) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.lost(peerID) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in self.stop() }
    }
}
