import SwiftUI

/// Red-LED scoreboard: score for each team, inning, ball/strike/out lamps and a message line.
struct ScoreboardView: View {
    @EnvironmentObject private var game: GameController

    var body: some View {
        let board = game.board
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                teamScore(.visitor, board: board)
                Spacer()
                VStack(spacing: 4) {
                    caption("INNING")
                    HStack(spacing: 4) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .foregroundColor(board.half == .top ? Theme.ledOn : Theme.ledOff)
                            Image(systemName: "arrowtriangle.down.fill")
                                .foregroundColor(board.half == .bottom ? Theme.ledOn : Theme.ledOff)
                        }
                        .font(.system(size: 9))
                        SevenSegmentNumber(value: board.inning, digits: 2, height: 34)
                    }
                }
                Spacer()
                teamScore(.home, board: board)
            }

            HStack(spacing: 18) {
                lamps("B", lit: board.balls, count: 3)
                lamps("S", lit: board.strikes, count: 2)
                lamps("O", lit: board.outs, count: 2)
            }

            Text(game.message.isEmpty ? " " : game.message)
                .font(Theme.ledFont(15))
                .foregroundColor(Theme.ledOn)
                .shadow(color: Theme.ledOn.opacity(0.7), radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(board))
    }

    private func teamScore(_ team: Team, board: GameState) -> some View {
        VStack(spacing: 4) {
            caption(team == .visitor ? "VIS · \(game.label(for: team))" : "HOME · \(game.label(for: team))")
            SevenSegmentNumber(value: board.score(of: team), digits: 2, height: 44)
            Circle()
                .fill(board.battingTeam == team && game.phase != .off ? Theme.ledOn : Theme.ledOff)
                .frame(width: 6, height: 6)
        }
    }

    private func lamps(_ title: String, lit: Int, count: Int) -> some View {
        HStack(spacing: 5) {
            caption(title)
            ForEach(0..<count, id: \.self) { index in
                LED(isOn: index < lit, diameter: 11)
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
    }

    private func accessibilityText(_ board: GameState) -> String {
        let half = board.half == .top ? "Top" : "Bottom"
        return "Visitor \(board.score(of: .visitor)), Home \(board.score(of: .home)). "
            + "\(half) of inning \(board.inning). "
            + "\(board.balls) balls, \(board.strikes) strikes, \(board.outs) outs. \(game.message)"
    }
}

/// A right-aligned number drawn with seven-segment digits; leading zeros are left dark.
struct SevenSegmentNumber: View {
    let value: Int
    let digits: Int
    let height: CGFloat

    var body: some View {
        let clamped = min(max(value, 0), Int(pow(10, Double(digits))) - 1)
        let text = String(clamped)
        let padded = Array(repeating: Character(" "), count: digits - text.count) + Array(text)
        HStack(spacing: height * 0.12) {
            ForEach(0..<padded.count, id: \.self) { index in
                SevenSegmentDigit(digit: padded[index].wholeNumberValue)
                    .frame(width: height * 0.55, height: height)
            }
        }
    }
}

/// One seven-segment digit. A nil digit shows all segments dark.
struct SevenSegmentDigit: View {
    let digit: Int?

    // Segments a b c d e f g as bits 0...6.
    private static let patterns: [UInt8] = [
        0b0111111, 0b0000110, 0b1011011, 0b1001111, 0b1100110,
        0b1101101, 0b1111101, 0b0000111, 0b1111111, 0b1101111,
    ]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let t = w * 0.18 // segment thickness
            let pattern = digit.map { Self.patterns[$0] } ?? 0

            // Each segment as a rect in the digit's box.
            let segments: [CGRect] = [
                CGRect(x: t, y: 0, width: w - 2 * t, height: t),                   // a
                CGRect(x: w - t, y: t, width: t, height: h / 2 - 1.5 * t),         // b
                CGRect(x: w - t, y: h / 2 + t / 2, width: t, height: h / 2 - 1.5 * t), // c
                CGRect(x: t, y: h - t, width: w - 2 * t, height: t),               // d
                CGRect(x: 0, y: h / 2 + t / 2, width: t, height: h / 2 - 1.5 * t), // e
                CGRect(x: 0, y: t, width: t, height: h / 2 - 1.5 * t),             // f
                CGRect(x: t, y: h / 2 - t / 2, width: w - 2 * t, height: t),       // g
            ]
            for (index, rect) in segments.enumerated() {
                let lit = pattern & (1 << index) != 0
                let path = Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: t / 2)
                context.fill(path, with: .color(lit ? Theme.ledOn : Theme.ledOff))
            }
        }
        .shadow(color: digit == nil ? .clear : Theme.ledOn.opacity(0.6), radius: 4)
    }
}
