import SwiftUI

/// Positions on the playing field in unit coordinates: (0, 0) is the top-left corner
/// of a square field view and (1, 1) the bottom-right. Multiply by the side length to draw.
enum FieldLayout {
    static let home = CGPoint(x: 0.50, y: 0.92)
    static let catcher = CGPoint(x: 0.50, y: 0.965)
    static let mound = CGPoint(x: 0.50, y: 0.715)
    /// First, second and third base.
    static let bases = [
        CGPoint(x: 0.71, y: 0.71),
        CGPoint(x: 0.50, y: 0.50),
        CGPoint(x: 0.29, y: 0.71),
    ]

    static let holeRadius: CGFloat = 0.034
    static let ledRadius: CGFloat = 0.026
    static let trackLEDRadius: CGFloat = 0.0095

    static func point(for spot: FieldSpot) -> CGPoint {
        switch spot {
        case .homeRun: return CGPoint(x: 0.50, y: 0.25)
        case .singleLeft: return CGPoint(x: 0.31, y: 0.30)
        case .singleRight: return CGPoint(x: 0.69, y: 0.30)
        case .centerField: return CGPoint(x: 0.50, y: 0.37)
        case .triple: return CGPoint(x: 0.14, y: 0.44)
        case .double: return CGPoint(x: 0.86, y: 0.44)
        case .leftField: return CGPoint(x: 0.27, y: 0.45)
        case .rightField: return CGPoint(x: 0.73, y: 0.45)
        case .shortstop: return CGPoint(x: 0.36, y: 0.54)
        case .secondBase: return CGPoint(x: 0.64, y: 0.54)
        case .thirdBase: return CGPoint(x: 0.26, y: 0.60)
        case .firstBase: return CGPoint(x: 0.74, y: 0.60)
        case .foulLeft: return CGPoint(x: 0.09, y: 0.60)
        case .foulRight: return CGPoint(x: 0.91, y: 0.60)
        case .pitcher: return mound
        }
    }

    /// LED positions along the pitch track. Indices `0..<trackLength` run from the mound to
    /// home plate; index `trackLength` is the catcher behind the plate.
    static func trackPoint(_ index: Int) -> CGPoint {
        if index >= PitchType.trackLength { return catcher }
        let start = CGPoint(x: 0.50, y: 0.775)
        let t = CGFloat(index) / CGFloat(PitchType.trackLength - 1)
        return CGPoint(x: start.x + (home.x - start.x) * t, y: start.y + (home.y - start.y) * t)
    }

    /// The green playing surface, fair and foul territory.
    static func fieldPath(side s: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0.50 * s, y: 1.00 * s))
        path.addLine(to: CGPoint(x: 0.00, y: 0.60 * s))
        path.addLine(to: CGPoint(x: 0.00, y: 0.50 * s))
        path.addQuadCurve(to: CGPoint(x: 1.00 * s, y: 0.50 * s),
                          control: CGPoint(x: 0.50 * s, y: -0.20 * s))
        path.addLine(to: CGPoint(x: 1.00 * s, y: 0.60 * s))
        path.closeSubpath()
        return path
    }
}

extension CGPoint {
    func scaled(_ side: CGFloat) -> CGPoint { CGPoint(x: x * side, y: y * side) }
}
