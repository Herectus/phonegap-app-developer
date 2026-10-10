import SwiftUI

enum Theme {
    static let background = Color(red: 0.05, green: 0.08, blue: 0.06)
    static let caseGreen = Color(red: 0.36, green: 0.62, blue: 0.20)
    static let field = Color(red: 0.13, green: 0.40, blue: 0.22)
    static let ledOn = Color(red: 1.00, green: 0.13, blue: 0.08)
    static let ledOff = Color(red: 0.24, green: 0.04, blue: 0.04)
    static let buttonOrange = Color(red: 0.97, green: 0.62, blue: 0.27)
    static let buttonOrangeDark = Color(red: 0.84, green: 0.45, blue: 0.14)
    static let cream = Color(red: 0.96, green: 0.90, blue: 0.62)

    static func ledFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }
}

/// A single red LED with a glow when lit.
struct LED: View {
    let isOn: Bool
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(isOn ? Theme.ledOn : Theme.ledOff)
            .overlay(
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(isOn ? 0.7 : 0.08), .clear],
                                         center: .init(x: 0.35, y: 0.35),
                                         startRadius: 0, endRadius: diameter * 0.45))
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: isOn ? Theme.ledOn.opacity(0.9) : .clear, radius: diameter * 0.5)
    }
}
