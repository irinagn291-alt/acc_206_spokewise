import SwiftUI

extension Path {
    /// Polyline through plot points expressed in 0…1, scaled into a canvas.
    /// Every Cartesian trace in Spokewise is drawn through this one call.
    static func rimTrail(_ points: [RimPoint], in size: CGSize) -> Path {
        var path = Path()
        for (position, point) in points.enumerated() {
            let landing = CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
            if position == 0 {
                path.move(to: landing)
            } else {
                path.addLine(to: landing)
            }
        }
        return path
    }

    /// Closed polar trace: a per-spoke series wrapped back to the valve.
    static func rimLoop(
        _ series: [Double],
        center: CGPoint,
        base: Double,
        gain: Double,
        scale: Double
    ) -> Path {
        var path = Path()
        let holes = series.count
        guard holes >= 3, scale != 0 else { return path }
        for step in 0...holes {
            let hole = step % holes
            let angle = RimPolarGeometry.spokeAngle(index: hole, count: holes)
            let reach = base + min(1, max(-1, series[hole] / scale)) * gain
            let landing = CGPoint(
                x: center.x + CGFloat(cos(angle) * reach),
                y: center.y + CGFloat(sin(angle) * reach)
            )
            if step == 0 { path.move(to: landing) } else { path.addLine(to: landing) }
        }
        return path
    }

    /// A ring centred on a point, used for every reference circle.
    static func rimRing(center: CGPoint, radius: Double) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - CGFloat(radius),
            y: center.y - CGFloat(radius),
            width: CGFloat(radius * 2),
            height: CGFloat(radius * 2)
        ))
    }
}
