import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var game: GameController
    @EnvironmentObject private var settings: GameSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showingMenu = false
    @FocusState private var keyboardFocus: Bool

    /// Larger controls when the window is iPad-sized in both directions.
    private var scale: CGFloat {
        horizontalSizeClass == .regular && verticalSizeClass == .regular ? 1.35 : 1
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if game.phase == .off {
                PowerOffView()
            } else {
                GeometryReader { geometry in
                    // iPad in landscape: field on the left, scoreboard and buttons on the right.
                    if geometry.size.width > geometry.size.height && geometry.size.width >= 700 {
                        landscapeLayout(width: geometry.size.width)
                    } else {
                        portraitLayout
                    }
                }
                .focusable()
                .focused($keyboardFocus)
                .focusEffectDisabled()
                .onKeyPress(phases: .down, action: handleKey)
                .onAppear { keyboardFocus = true }
            }
        }
        .environment(\.uiScale, scale)
        .confirmationDialog(game.isNearbyGameInProgress ? "Quitting now forfeits the game." : "Game",
                            isPresented: $showingMenu,
                            titleVisibility: game.isNearbyGameInProgress ? .visible : .hidden) {
            if game.isNearbyGameInProgress {
                Button("Quit and Forfeit", role: .destructive) { game.forfeit() }
            } else {
                Button("New Game") { game.newGame() }
                Button("Power Off", role: .destructive) { game.powerOff() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .background: game.appEnteredBackground()
            case .active: game.appBecameActive()
            default: break
            }
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 12) {
            topBar
            ScoreboardView()
            FieldView()
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: .infinity)
            controls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: scale > 1 ? 820 : 600)
        .frame(maxWidth: .infinity)
    }

    private func landscapeLayout(width: CGFloat) -> some View {
        HStack(spacing: 24) {
            FieldView()
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 16) {
                topBar
                ScoreboardView()
                Spacer(minLength: 0)
                controls
            }
            .frame(width: min(480, width * 0.42))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var controls: some View {
        if game.phase == .gameOver {
            RetroButton(title: game.isNearbyGuest ? "ASK HOST FOR NEW GAME" : "NEW GAME",
                        height: 64) { game.newGame() }
        } else if let delay = game.rainDelay {
            RainDelayView(delay: delay)
        } else {
            ControlPanel()
        }
    }

    /// Hardware keyboard (for example an iPad keyboard case): Space swings, S steals,
    /// 1/2/3 or F/C/V pitch fast, change-up or curve.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.characters.lowercased() {
        case " ": game.swing()
        case "s": game.steal()
        case "1", "f": game.pitch(.fastball)
        case "2", "c": game.pitch(.changeUp)
        case "3", "v": game.pitch(.curve)
        default: return .ignored
        }
        return .handled
    }

    private var topBar: some View {
        HStack {
            Button {
                showingMenu = true
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 18 * scale, weight: .bold))
                    .foregroundColor(Theme.buttonOrange)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Game menu")

            Spacer()
            Text(game.modeLabel)
                .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Spacer()

            Button {
                settings.soundOn.toggle()
            } label: {
                Image(systemName: settings.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16 * scale, weight: .bold))
                    .foregroundColor(Theme.buttonOrange)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(settings.soundOn ? "Mute sound" : "Turn sound on")
        }
    }
}

/// The "switched off" screen: game options and the power switch.
struct PowerOffView: View {
    @Environment(\.uiScale) private var scale
    @EnvironmentObject private var game: GameController
    @EnvironmentObject private var settings: GameSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("BASEBALL 2")
                        .font(Theme.ledFont(40 * scale))
                        .foregroundColor(Theme.ledOn)
                        .shadow(color: Theme.ledOn.opacity(0.7), radius: 8)
                    Text("ELECTRONIC HANDHELD")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 24)

                optionGroup("GAME") {
                    Picker("Game", selection: $settings.mode) {
                        Text("VS CPU").tag(GameSettings.Mode.auto)
                        Text("2P · 1 DEVICE").tag(GameSettings.Mode.manual)
                        Text("2P · 2 DEVICES").tag(GameSettings.Mode.nearby)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.mode) { game.cancelNearby() }
                }

                optionGroup("INNINGS") {
                    Picker("Innings", selection: $settings.innings) {
                        ForEach(GameSettings.inningChoices, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if settings.mode == .auto {
                    optionGroup("CPU") {
                        Picker("CPU skill", selection: $settings.cpuSkill) {
                            ForEach(GameSettings.Skill.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                VStack(spacing: 4) {
                    Toggle("Sound", isOn: $settings.soundOn)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        Toggle("Haptics", isOn: $settings.hapticsOn)
                    }
                }
                .tint(Theme.buttonOrange)
                .foregroundColor(.white)

                if let notice = game.notice {
                    Text(notice)
                        .font(Theme.ledFont(16 * scale))
                        .foregroundColor(Theme.ledOn)
                }

                if settings.mode == .nearby {
                    NearbyLobbyView(nearby: game.nearby)
                    RecordsView(records: game.records)
                } else {
                    RetroButton(title: "POWER ON", height: 64) { game.powerOn() }
                }

                howToPlay
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    private func optionGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            content()
        }
    }

    private var howToPlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW TO PLAY")
                .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Group {
                Text("• The pitcher picks FAST, CHANGE or CURVE. The ball runs down the LED track toward the plate.")
                Text("• Tap SWING as the ball reaches the plate. The closer your timing, the harder the hit. Swing early to pull it left, late to go the other way.")
                Text("• Don't swing and the umpire calls a ball or strike. 4 balls walks, 3 strikes is an out.")
                Text("• With a runner on, tap STEAL during the pitch. Steals work best on slow pitches.")
                Text("• Keyboard (iPad): Space swings, S steals, 1 / 2 / 3 throw fast, change-up and curve.")
                Text("• VS CPU: you bat in the top half and pitch in the bottom against the computer.")
                Text("• 2P · 1 DEVICE: two players share this iPhone or iPad.")
                Text("• 2P · 2 DEVICES: each player uses their own iPhone or iPad in the same room (iPhone vs iPad works too). One taps HOST GAME, the other taps JOIN GAME. The host bats first.")
                Text("• In a 2-device game, quitting or leaving the app before the last out forfeits: you take the loss and your rival gets the win. A phone call or lost connection is a rain delay instead: when it's over, both players have 60 seconds to tap RESUME.")
            }
            .font(.system(size: 14 * scale, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
