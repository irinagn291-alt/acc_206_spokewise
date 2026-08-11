import Foundation

/// The spoke as three points in the wheel's own plane, viewed face on, plus
/// the two lengths that fall out of it.
public struct SpokeTriangle: Sendable, Hashable {
    public let axle: RimPoint
    public let flangeHole: RimPoint
    public let rimSeat: RimPoint
    public let chordMm: Double
    public let lengthMm: Double
    public let flangeAngle: Double

    public init(
        axle: RimPoint,
        flangeHole: RimPoint,
        rimSeat: RimPoint,
        chordMm: Double,
        lengthMm: Double,
        flangeAngle: Double
    ) {
        self.axle = axle
        self.flangeHole = flangeHole
        self.rimSeat = rimSeat
        self.chordMm = chordMm
        self.lengthMm = lengthMm
        self.flangeAngle = flangeAngle
    }
}

/// Lays the length calculation out as the triangle a builder would sketch:
/// axle, flange hole, nipple seat. Millimetres throughout.
public enum SpokeTriangleMath: Sendable {

    /// Angle subtended at the axle between a flange hole and its rim seat.
    public static func flangeAngle(spokeCount: Int, cross: Int) -> Double {
        2 * Double.pi * Double(max(cross, 0)) / Double(max(spokeCount, 1))
    }

    public static func triangle(
        erdMm: Double,
        flangeDiameterMm: Double,
        offsetMm: Double,
        holeMm: Double,
        spokeCount: Int,
        cross: Int
    ) -> SpokeTriangle {
        let rimRadius = max(erdMm, 0) / 2
        let flangeRadius = max(flangeDiameterMm, 0) / 2
        let angle = flangeAngle(spokeCount: spokeCount, cross: cross)
        let chordSquared = rimRadius * rimRadius + flangeRadius * flangeRadius
            - 2 * rimRadius * flangeRadius * cos(angle)
        let chord = sqrt(max(0, chordSquared))
        let length = sqrt(chord * chord + offsetMm * offsetMm) - max(holeMm, 0) / 2
        return SpokeTriangle(
            axle: RimPoint(x: 0, y: 0),
            flangeHole: RimPoint(x: flangeRadius * cos(angle), y: flangeRadius * sin(angle)),
            rimSeat: RimPoint(x: rimRadius, y: 0),
            chordMm: round(chord * 10) / 10,
            lengthMm: round(length * 10) / 10,
            flangeAngle: angle
        )
    }
}

/// The tensiometer's deflection→kgf table as a curve with draggable knots.
public enum CalibrationCurveMath: Sendable {
    public static let deflectionRange: ClosedRange<Double> = 5...40
    public static let kgfRange: ClosedRange<Double> = 20...180

    /// Table knots as 0…1 plot coordinates, y already flipped for the screen.
    public static func plotted(_ pairs: [(deflection: Double, kgf: Double)]) -> [RimPoint] {
        pairs.map { pair in
            RimPoint(
                x: unit(pair.deflection, in: deflectionRange),
                y: 1 - unit(pair.kgf, in: kgfRange)
            )
        }
    }

    /// Knot nearest a touch in plot space, or nil if the touch missed.
    public static func nearestKnot(to point: RimPoint, among knots: [RimPoint], within radius: Double = 0.14) -> Int? {
        var best: (index: Int, distance: Double)?
        for (index, knot) in knots.enumerated() {
            let distance = hypot(knot.x - point.x, knot.y - point.y)
            if best == nil || distance < best!.distance { best = (index, distance) }
        }
        guard let best, best.distance <= radius else { return nil }
        return best.index
    }

    /// kgf a vertical drag lands on, snapped to whole kilograms and kept
    /// monotonic against its neighbours so the table stays invertible.
    public static func draggedKgf(
        plotY: Double,
        index: Int,
        in pairs: [(deflection: Double, kgf: Double)]
    ) -> Double {
        let raw = kgfRange.lowerBound
            + (1 - min(1, max(0, plotY))) * (kgfRange.upperBound - kgfRange.lowerBound)
        var low = kgfRange.lowerBound
        var high = kgfRange.upperBound
        if index > 0 { low = max(low, pairs[index - 1].kgf + 1) }
        if index < pairs.count - 1 { high = min(high, pairs[index + 1].kgf - 1) }
        guard low <= high else { return pairs[index].kgf }
        return min(high, max(low, raw.rounded()))
    }

    /// Back to the two CSV columns the calibration row stores.
    public static func columns(_ pairs: [(deflection: Double, kgf: Double)]) -> (deflection: String, kgf: String) {
        (
            deflection: pairs.map { String(format: "%.1f", $0.deflection) }.joined(separator: ","),
            kgf: pairs.map { String(format: "%.0f", $0.kgf) }.joined(separator: ",")
        )
    }

    private static func unit(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }
}

/// Shared scaling for the two Cartesian plots: the compare overlay and the
/// truing trace's unrolled view.
public enum RimProfileMath: Sendable {

    /// Plot points for a per-spoke series, x by index and y scaled to the
    /// band the series occupies, flipped for the screen.
    public static func profile(_ series: [Double], band: ClosedRange<Double>) -> [RimPoint] {
        guard !series.isEmpty else { return [] }
        let span = band.upperBound - band.lowerBound
        let lastIndex = Double(max(series.count - 1, 1))
        return series.enumerated().map { index, value in
            let y = span > 0 ? (value - band.lowerBound) / span : 0.5
            return RimPoint(
                x: series.count > 1 ? Double(index) / lastIndex : 0.5,
                y: 1 - min(1, max(0, y))
            )
        }
    }

    /// A band that contains every series with a little air above and below.
    public static func band(_ series: [[Double]], padding: Double = 0.08) -> ClosedRange<Double> {
        let flat = series.flatMap { $0 }
        guard let low = flat.min(), let high = flat.max() else { return 0...1 }
        if high - low < 0.0001 { return (low - 1)...(high + 1) }
        let pad = (high - low) * padding
        return (low - pad)...(high + pad)
    }
}
