# Baseball 2: retro LED handheld for iOS

A native SwiftUI remake of a classic red-LED electronic baseball handheld. The field
layout follows a photo of the original game's printed overlay: HR, SINGLE, DOUBLE, TRIPLE and
FOUL holes, the LF/CF/RF/SS/2B/3B/1B fielder holes, a pitch track running from the
mound to the plate, and a red scoreboard. There is no artwork from the original;
everything is drawn in code and the sounds are synthesized square waves.

## Build and run

Requirements: a Mac with **Xcode 16 or later**, targeting **iOS 17+**.

1. Open `MegoBaseball/MegoBaseball.xcodeproj` in Xcode.
2. Select the **MegoBaseball** target → *Signing & Capabilities*, choose your Team, and
   change the bundle identifier (`com.example.MegoBaseball`) to one you own.
3. Pick an iPhone simulator or your device and press **Run** (⌘R).
4. Run the rules tests with **Product → Test** (⌘U).

The project uses Xcode 16 folder-synced groups, so any `.swift` file you add under
`MegoBaseball/` or `MegoBaseballTests/` is picked up automatically.

## How to play

| Control | What it does |
| --- | --- |
| **FAST / CHANGE / CURVE** | Pitcher throws. Fastballs are quick, change-ups are slow, curves hang then break late. |
| **SWING** | Fires the moment you touch it. Time it to the ball reaching the plate. |
| **STEAL** | During a pitch, the lead runner takes off. Works best on slow pitches. |
| ⏻ (top left) | New game or power off. In a nearby game, power off disconnects both phones. |

* **Timing:** within ±35 ms is a *perfect* swing (home runs, extra bases), ±80 ms is
  *good*, ±140 ms gets a piece of it (fouls, grounders). Early swings pull the ball to
  left, late swings go to right.
* **Taking a pitch:** the umpire calls ball or strike. 4 balls walks, 3 strikes is an
  out, and a foul with two strikes stays two strikes.
* **Running the bases:** runners advance as many bases as the hit. A fly out scores a
  runner from third with fewer than two outs. A grounder with a runner on first can
  be a double play; otherwise runners move up a base.
* **Game length:** 3, 6 or 9 innings (default 9), with extra innings on a tie and a
  walk-off when the home team takes the lead in the last inning.

### Modes

* **AUTO, vs. CPU:** you are the visitor. You bat in the top half while the computer
  pitches, and you pitch in the bottom half while the computer bats. Choose a
  **ROOKIE** or **PRO** computer batter.
* **2P · 1 PHONE (manual):** pass-and-play. P1 is the visitor and P2 is home; whoever is in
  the field uses the pitch buttons and whoever is up uses SWING and STEAL.
* **2P · 2 PHONES (nearby):** each player on their own iPhone in the same room, connected
  directly over Wi-Fi or Bluetooth with Apple's Multipeer Connectivity. No internet,
  account or server is needed. See below.

Sound follows the ring/silent switch and can be muted from the top bar. Haptics can
be turned off on the power-off screen.

## Playing on two iPhones

1. Install the app on both iPhones (build to each one from Xcode).
2. On both phones choose **2P · 2 PHONES**. Turn on Wi-Fi or Bluetooth on both.
3. Phone 1 taps **HOST GAME**. Phone 2 taps **JOIN GAME**, then taps phone 1's name.
4. The first time, iOS asks to allow **Local Network** access. Tap **Allow** on both phones.
5. The game starts on both phones. The host is the visitor and bats first, and the host's
   innings setting is used.

Each phone shows the same field and scoreboard. Only the pitcher's phone has working pitch
buttons and only the batter's phone has SWING and STEAL. The batter sees "HERE'S THE PITCH",
not which pitch was thrown.

How it stays fair: the host phone keeps the official score and makes the random rolls.
When a pitch is thrown, both phones animate it, and the **batter's own phone** times the
swing against its own animation, then sends the result. Network delay therefore never
makes a swing early or late. Leaving the app mid-game forfeits (see below). If the
connection simply drops, both phones show **CONNECTION LOST · NO RESULT**.

### Quitting and head-to-head records

* **Quitting forfeits.** In a 2-phone game, choosing **Quit and Forfeit** from the ⏻ menu,
  or leaving the app (home screen, switching apps, locking the phone) before the final out,
  forfeits the game. The quitter gets a loss and the other player gets a win.
* **A lost connection is not a forfeit.** If the phones drop out of range or Wi-Fi turns
  off and no forfeit message arrives, the game ends with **NO RESULT** for both players.
* **Records per player pair.** Each phone gets a permanent player ID and a name you can set
  on the 2P · 2 PHONES screen. When phones connect they swap IDs, and each phone keeps
  your wins and losses against every opponent under **HEAD-TO-HEAD RECORDS**, with
  forfeits also counted separately (FF). Renaming yourself keeps your record. The top bar
  shows the current matchup, for example `VS SAM · 3-2`.
* Records are stored only on each phone, so deleting the app erases them. **Clear**
  erases them on purpose.

## Code layout

```
MegoBaseball/
  MegoBaseballApp.swift        App entry point
  Engine/                      Pure Swift rules, no UI or timing (unit tested)
    GameModels.swift           Pitches, field spots, outcomes, swing timing windows
    Rules.swift                Swing timing → batted-ball outcome tables
    GameState.swift            Count, outs, bases, score, innings, steals, game end
  Game/GameController.swift    Real-time loop: pitch flight, CPU opponent, animations, nearby play
  Network/                     Multipeer Connectivity service and the messages the phones exchange
  Support/                     Field geometry, square-wave sound, haptics, settings, records
  Views/                       Field, scoreboard (7-segment digits), buttons, menu
MegoBaseballTests/             XCTest suite for the engine
```

To tune difficulty, adjust the pitch speeds in `PitchType.baseIntervals`, the timing
windows in `SwingTiming`, or the outcome weights in `Rules.outcome`.
