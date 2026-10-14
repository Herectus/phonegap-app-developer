import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameController
    @EnvironmentObject private var settings: GameSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMenu = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if game.phase == .off {
                PowerOffView()
            } else {
                VStack(spacing: 12) {
                    topBar
                    ScoreboardView()
                    FieldView()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxHeight: .infinity)
                    if game.phase == .gameOver {
                        RetroButton(title: game.isNearbyGuest ? "ASK HOST FOR NEW GAME" : "NEW GAME",
                                    height: 64) { game.newGame() }
                    } else if let delay = game.rainDelay {
                        RainDelayView(delay: delay)
                    } else {
                        ControlPanel()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: 600)
            }
        }
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

    private var topBar: some View {
        HStack {
            Button {
                showingMenu = true
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.buttonOrange)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Game menu")

            Spacer()
            Text(game.modeLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Spacer()

            Button {
                settings.soundOn.toggle()
            } label: {
                Image(systemName: settings.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.buttonOrange)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(settings.soundOn ? "Mute sound" : "Turn sound on")
        }
    }
}

/// The "switched off" screen: game options and the power switch.
struct PowerOffView: View {
    @EnvironmentObject private var game: GameController
    @EnvironmentObject private var settings: GameSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("BASEBALL 2")
                        .font(Theme.ledFont(40))
                        .foregroundColor(Theme.ledOn)
                        .shadow(color: Theme.ledOn.opacity(0.7), radius: 8)
                    Text("ELECTRONIC HANDHELD")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 24)

                optionGroup("GAME") {
                    Picker("Game", selection: $settings.mode) {
                        Text("VS CPU").tag(GameSettings.Mode.auto)
                        Text("2P · 1 PHONE").tag(GameSettings.Mode.manual)
                        Text("2P · 2 PHONES").tag(GameSettings.Mode.nearby)
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
                    Toggle("Haptics", isOn: $settings.hapticsOn)
                }
                .tint(Theme.buttonOrange)
                .foregroundColor(.white)

                if let notice = game.notice {
                    Text(notice)
                        .font(Theme.ledFont(16))
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            content()
        }
    }

    private var howToPlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW TO PLAY")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Group {
                Text("• The pitcher picks FAST, CHANGE or CURVE. The ball runs down the LED track toward the plate.")
                Text("• Tap SWING as the ball reaches the plate. The closer your timing, the harder the hit. Swing early to pull it left, late to go the other way.")
                Text("• Don't swing and the umpire calls a ball or strike. 4 balls walks, 3 strikes is an out.")
                Text("• With a runner on, tap STEAL during the pitch. Steals work best on slow pitches.")
                Text("• VS CPU: you bat in the top half and pitch in the bottom against the computer.")
                Text("• 2P · 1 PHONE: two players share this phone.")
                Text("• 2P · 2 PHONES: each player uses their own iPhone in the same room. One taps HOST GAME, the other taps JOIN GAME. The host bats first.")
                Text("• In a 2-phone game, quitting or leaving the app before the last out forfeits: you take the loss and your rival gets the win. A lost connection doesn't count for either player.")
            }
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
