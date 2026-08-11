import Foundation

/// A point in the rim map's own space, y increasing downward as on screen.
public struct RimPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// One spoke's measured state, ordered clockwise from the valve hole.
public struct RimSample: Sendable, Hashable {
    public let index: Int
    public let side: SpokeSide
    public let tensionKgf: Double
    public let deflection: Double
    public let lateralMm: Double
    public let radialMm: Double
    public let isMeasured: Bool

    public init(
        index: Int,
        side: SpokeSide,
        tensionKgf: Double,
        deflection: Double,
        lateralMm: Double,
        radialMm: Double,
        isMeasured: Bool
    ) {
        self.index = index
        self.side = side
        self.tensionKgf = tensionKgf
        self.deflection = deflection
        self.lateralMm = lateralMm
        self.radialMm = radialMm
        self.isMeasured = isMeasured
    }

    /// The value the dial edits under a given lens.
    public func dialValue(for lens: RimLens) -> Double {
        switch lens {
        case .tension: return deflection
        case .dish: return lateralMm
        case .trueness: return radialMm
        }
    }
}

/// Positions every element of the polar spoke map. Pure, so the `Canvas`
/// closure only has to draw what these functions return.
public enum RimPolarGeometry: Sendable {

    /// Angle of spoke `index`: the valve sits at 12 o'clock and indices
    /// advance clockwise, matching how a wheel is walked on the stand.
    public static func spokeAngle(index: Int, count: Int) -> Double {
        let n = max(count, 1)
        let wrapped = ((index % n) + n) % n
        return -Double.pi / 2 + 2 * Double.pi * Double(wrapped) / Double(n)
    }

    /// Spokes alternate flanges around the rim; even holes lace drive side.
    public static func lacedSide(index: Int) -> SpokeSide {
        let wrapped = ((index % 2) + 2) % 2
        return wrapped == 0 ? .drive : .nonDrive
    }

    /// Tangential lead of a spoke's hub anchor, signed so the two flanges
    /// wind in opposite directions. Each flange carries half the spokes.
    public static func lacingLead(count: Int, cross: Int, side: SpokeSide) -> Double {
        let perFlange = max(count / 2, 1)
        let magnitude = 2 * Double.pi * Double(max(cross, 0)) / Double(perFlange)
        return side == .drive ? magnitude : -magnitude
    }

    /// Where a spoke meets the rim: straight out along its own hole angle.
    public static func rimAnchor(index: Int, count: Int, center: RimPoint, rimRadius: Double) -> RimPoint {
        polar(center: center, radius: rimRadius, angle: spokeAngle(index: index, count: count))
    }

    /// Where a spoke leaves the hub flange, swung round by its lacing lead.
    public static func hubAnchor(
        index: Int,
        count: Int,
        cross: Int,
        side: SpokeSide,
        center: RimPoint,
        hubRadius: Double
    ) -> RimPoint {
        let angle = spokeAngle(index: index, count: count)
            + lacingLead(count: count, cross: cross, side: side)
        return polar(center: center, radius: hubRadius, angle: angle)
    }

    /// Closed rim-deviation outline: one vertex per spoke, swung off the
    /// reference circle by that spoke's normalised deviation.
    public static func deviationPolygon(
        normalized: [Double],
        center: RimPoint,
        referenceRadius: Double,
        span: Double
    ) -> [RimPoint] {
        let count = normalized.count
        guard count >= 3 else { return [] }
        return normalized.enumerated().map { index, deviation in
            polar(
                center: center,
                radius: vertexRadius(normalized: deviation, referenceRadius: referenceRadius, span: span),
                angle: spokeAngle(index: index, count: count)
            )
        }
    }

    /// Radius of one polygon vertex. Deviation is clamped so a wild reading
    /// cannot push the outline off the rim.
    public static func vertexRadius(normalized: Double, referenceRadius: Double, span: Double) -> Double {
        let clamped = min(1, max(-1, normalized))
        return max(0, referenceRadius + clamped * span)
    }

    /// Spoke the builder meant when they tapped the map.
    public static func nearestSpoke(to point: RimPoint, center: RimPoint, count: Int) -> Int {
        let n = max(count, 1)
        var angle = atan2(point.y - center.y, point.x - center.x) + Double.pi / 2
        let turn = 2 * Double.pi
        angle = angle.truncatingRemainder(dividingBy: turn)
        if angle < 0 { angle += turn }
        let step = turn / Double(n)
        return Int((angle / step).rounded()) % n
    }

    /// Stretch a runout trace of any length onto `count` equally spaced
    /// spokes, wrapping at the valve because the rim is a loop.
    public static func resample(_ trace: [Double], to count: Int) -> [Double] {
        guard count > 0 else { return [] }
        guard let first = trace.first else { return Array(repeating: 0, count: count) }
        guard trace.count > 1 else { return Array(repeating: first, count: count) }
        let n = trace.count
        return (0..<count).map { index in
            let position = Double(index) * Double(n) / Double(count)
            let lower = Int(position.rounded(.down))
            let fraction = position - Double(lower)
            let a = trace[lower % n]
            let b = trace[(lower + 1) % n]
            return a + (b - a) * fraction
        }
    }

    /// Runout the stand should record for a drag `reach` from the hub, where
    /// `base` is the nominal rim and `gain` is one full-scale deflection.
    public static func runout(
        reach: Double,
        base: Double,
        gain: Double,
        fullScale: Double,
        step: Double
    ) -> Double {
        guard gain > 0, fullScale > 0 else { return 0 }
        let raw = ((reach - base) / gain) * fullScale
        let clamped = min(fullScale, max(-fullScale, raw))
        guard step > 0 else { return clamped }
        return (clamped / step).rounded() * step
    }

    /// Serialise a trace back into the stored CSV column.
    public static func csv(_ trace: [Double]) -> String {
        trace.map { String(format: "%.2f", $0) }.joined(separator: ",")
    }

    private static func polar(center: RimPoint, radius: Double, angle: Double) -> RimPoint {
        RimPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
