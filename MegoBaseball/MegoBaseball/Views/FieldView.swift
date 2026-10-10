import SwiftUI

/// The playing field with its LED holes, base runners and pitch track.
struct FieldView: View {
    @EnvironmentObject private var game: GameController

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                FieldArt()

                ForEach(FieldSpot.allCases) { spot in
                    LED(isOn: game.litSpot == spot, diameter: FieldLayout.ledRadius * 2 * side)
                        .position(FieldLayout.point(for: spot).scaled(side))
                }

                // Runners blink while a steal is on.
                TimelineView(.periodic(from: .now, by: 0.12)) { context in
                    let blinkOn = Int(context.date.timeIntervalSinceReferenceDate / 0.12) % 2 == 0
                    ZStack {
                        ForEach(0..<3, id: \.self) { base in
                            let occupied = game.board.bases[base]
                            let stealing = game.stealingBase == base
                            LED(isOn: occupied && (!stealing || blinkOn),
                                diameter: FieldLayout.ledRadius * 2 * side)
                                .position(FieldLayout.bases[base].scaled(side))
                        }
                    }
                }

                ForEach(0...PitchType.trackLength, id: \.self) { index in
                    LED(isOn: game.ballIndex == index, diameter: FieldLayout.trackLEDRadius * 2 * side)
                        .position(FieldLayout.trackPoint(index).scaled(side))
                }

                if let ball = game.battedBallPosition {
                    LED(isOn: true, diameter: FieldLayout.ledRadius * 1.4 * side)
                        .position(ball.scaled(side))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let names = ["first", "second", "third"]
        let runners = (0..<3).filter { game.board.bases[$0] }.map { names[$0] }
        return runners.isEmpty ? "Bases empty" : "Runners on " + runners.joined(separator: " and ")
    }
}

/// The static artwork: grass, base paths, foul lines, labels and the holes the LEDs sit in.
private struct FieldArt: View {
    var body: some View {
        Canvas { context, size in
            let s = size.width
            func p(_ point: CGPoint) -> CGPoint { point.scaled(s) }

            let field = FieldLayout.fieldPath(side: s)
            context.fill(field, with: .color(Theme.field))

            var inside = context
            inside.clip(to: field)

            // Foul lines run from home through first and third out to the wall.
            var foulLines = Path()
            for base in [FieldLayout.bases[0], FieldLayout.bases[2]] {
                let dx = base.x - FieldLayout.home.x
                let dy = base.y - FieldLayout.home.y
                foulLines.move(to: p(FieldLayout.home))
                foulLines.addLine(to: p(CGPoint(x: FieldLayout.home.x + dx * 4, y: FieldLayout.home.y + dy * 4)))
            }
            inside.stroke(foulLines, with: .color(.white), lineWidth: s * 0.006)

            // Black base paths edged in white, like the printed overlay.
            var diamond = Path()
            diamond.move(to: p(FieldLayout.home))
            for base in FieldLayout.bases { diamond.addLine(to: p(base)) }
            diamond.closeSubpath()
            inside.stroke(diamond, with: .color(.white), style: StrokeStyle(lineWidth: s * 0.046, lineJoin: .miter))
            inside.stroke(diamond, with: .color(.black), style: StrokeStyle(lineWidth: s * 0.034, lineJoin: .miter))

            // Pitch track from the mound to the plate.
            var track = Path()
            track.move(to: p(FieldLayout.mound))
            track.addLine(to: p(FieldLayout.catcher))
            inside.stroke(track, with: .color(.white), style: StrokeStyle(lineWidth: s * 0.044, lineCap: .round))
            inside.stroke(track, with: .color(.black), style: StrokeStyle(lineWidth: s * 0.034, lineCap: .round))

            // Mound.
            let moundRadius = s * 0.045
            let mound = Path(ellipseIn: CGRect(x: p(FieldLayout.mound).x - moundRadius,
                                               y: p(FieldLayout.mound).y - moundRadius,
                                               width: moundRadius * 2, height: moundRadius * 2))
            inside.fill(mound, with: .color(.black))
            inside.stroke(mound, with: .color(.white), lineWidth: s * 0.005)

            // Bases.
            for base in FieldLayout.bases {
                let center = p(base)
                let half = s * 0.022
                var square = Path()
                square.move(to: CGPoint(x: center.x, y: center.y - half))
                square.addLine(to: CGPoint(x: center.x + half, y: center.y))
                square.addLine(to: CGPoint(x: center.x, y: center.y + half))
                square.addLine(to: CGPoint(x: center.x - half, y: center.y))
                square.closeSubpath()
                inside.stroke(square, with: .color(.white), lineWidth: s * 0.005)
            }

            // Batter's boxes either side of the plate.
            let home = p(FieldLayout.home)
            for side in [-1.0, 1.0] {
                let box = CGRect(x: home.x + CGFloat(side) * s * 0.055 - s * 0.022,
                                 y: home.y - s * 0.035, width: s * 0.044, height: s * 0.07)
                inside.stroke(Path(box), with: .color(.white), lineWidth: s * 0.005)
            }

            // Holes and labels.
            let labelFont = Font.system(size: s * 0.03, weight: .bold, design: .rounded)
            for spot in FieldSpot.allCases where spot != .pitcher {
                let center = p(FieldLayout.point(for: spot))
                let r = FieldLayout.holeRadius * s
                let hole = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                inside.fill(hole, with: .color(.black))
                inside.stroke(hole, with: .color(.white), lineWidth: s * 0.006)
                // Foul holes sit near the edge of the field, so their labels go on top.
                let offset = r + s * 0.022
                let labelY = spot == .foulLeft || spot == .foulRight ? center.y - offset : center.y + offset
                inside.draw(Text(spot.label).font(labelFont).foregroundColor(.white),
                            at: CGPoint(x: center.x, y: labelY))
            }
            inside.draw(Text("PITCHER").font(labelFont).foregroundColor(.white),
                        at: CGPoint(x: p(FieldLayout.mound).x, y: p(FieldLayout.mound).y - s * 0.07))

            context.stroke(field, with: .color(Theme.cream), lineWidth: s * 0.012)
        }
    }
}
