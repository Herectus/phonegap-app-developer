import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameController
    @EnvironmentObject private var settings: GameSettings
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
                        RetroButton(title: "NEW GAME", height: 64) { game.newGame() }
                    } else {
                        ControlPanel()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: 600)
            }
        }
        .confirmationDialog("Game", isPresented: $showingMenu, titleVisibility: .hidden) {
            Button("New Game") { game.newGame() }
            Button("Power Off", role: .destructive) { game.powerOff() }
            Button("Cancel", role: .cancel) {}
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
            Text(game.isTwoPlayer ? "MANUAL · 2 PLAYER" : "AUTO · VS CPU")
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
                        Text("AUTO · VS CPU").tag(GameSettings.Mode.auto)
                        Text("MANUAL · 2 PLAYER").tag(GameSettings.Mode.manual)
                    }
                    .pickerStyle(.segmented)
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

                RetroButton(title: "POWER ON", height: 64) { game.powerOn() }

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
                Text("• AUTO: you bat in the top half and pitch in the bottom against the computer. MANUAL: two players share the phone.")
            }
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
