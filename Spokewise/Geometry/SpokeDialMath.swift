import Foundation

/// The dial that opens when a spoke on the map is tapped. A 270° sweep
/// starting at the lower left, so the two ends never meet under the thumb.
public enum SpokeDialMath: Sendable {
    public static let startAngle = 3 * Double.pi / 4
    public static let sweep = 3 * Double.pi / 2

    /// Angle on the dial for a 0…1 position along its travel.
    public static func angle(forFraction fraction: Double) -> Double {
        startAngle + clampUnit(fraction) * sweep
    }

    /// Position along the dial's travel for a touch angle, clamped at the ends
    /// so dragging past the gap does not wrap round to the other extreme.
    public static func fraction(forAngle angle: Double) -> Double {
        let turn = 2 * Double.pi
        var offset = (angle - startAngle).truncatingRemainder(dividingBy: turn)
        if offset < 0 { offset += turn }
        if offset > sweep {
            return offset - sweep > (turn - sweep) / 2 ? 0 : 1
        }
        return offset / sweep
    }

    /// Position of a touch relative to the dial centre.
    public static func fraction(at point: RimPoint, center: RimPoint) -> Double {
        fraction(forAngle: atan2(point.y - center.y, point.x - center.x))
    }

    /// Value at a dial position, snapped to the lens' step.
    public static func value(forFraction fraction: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let raw = range.lowerBound + clampUnit(fraction) * (range.upperBound - range.lowerBound)
        guard step > 0 else { return raw }
        let snapped = (raw / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, round(snapped * 1000) / 1000))
    }

    /// Dial position showing a value.
    public static func fraction(forValue value: Double, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return clampUnit((value - range.lowerBound) / span)
    }

    /// Nudge the dial by whole steps for the fine buttons either side.
    public static func stepped(_ value: Double, by steps: Int, range: ClosedRange<Double>, step: Double) -> Double {
        let moved = value + Double(steps) * step
        return min(range.upperBound, max(range.lowerBound, round(moved * 1000) / 1000))
    }

    private static func clampUnit(_ value: Double) -> Double { min(1, max(0, value)) }
}
