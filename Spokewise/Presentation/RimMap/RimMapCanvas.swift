import SwiftUI

/// The polar spoke map. Rim circle, dashed reference circle, hub ring, one
/// line per spoke coloured by flange, and the closed rim-deviation outline
/// over the top. Proportions come from the prototype's 300-unit viewBox.
struct RimMapCanvas: View {
    let samples: [RimSample]
    let cross: Int
    let lens: RimLens
    var selected: Int?
    var weight: CGFloat = 1

    private enum Ring {
        static let viewBox: Double = 300
        static let rim: Double = 128
        static let reference: Double = 96
        static let hub: Double = 28
        static let outline: Double = 112
        static let swing: Double = 12
        static let hubDot: Double = 7.5
    }

    var body: some View {
        Canvas { context, size in
            let unit = Double(min(size.width, size.height)) / Ring.viewBox
            let center = RimPoint(x: Double(size.width) / 2, y: Double(size.height) / 2)
            let rimRadius = Ring.rim * unit
            let hubRadius = Ring.hub * unit
            let count = samples.count

            stroke(&context, radius: Ring.rim * unit, center: center,
                   color: AnodisedInk.rimHairline, style: StrokeStyle(lineWidth: 1 * weight))
            stroke(&context, radius: Ring.reference * unit, center: center,
                   color: AnodisedInk.innerHairline,
                   style: StrokeStyle(lineWidth: 1 * weight, dash: [CGFloat(3 * unit), CGFloat(4 * unit)]))
            stroke(&context, radius: hubRadius, center: center,
                   color: AnodisedInk.hubRing, style: StrokeStyle(lineWidth: 1.5 * weight))

            guard count > 0 else { return }

            for side in [SpokeSide.drive, SpokeSide.nonDrive] {
                var lines = Path()
                for sample in samples where sample.side == side {
                    lines.move(to: screen(RimPolarGeometry.hubAnchor(
                        index: sample.index, count: count, cross: cross,
                        side: sample.side, center: center, hubRadius: hubRadius
                    )))
                    lines.addLine(to: screen(RimPolarGeometry.rimAnchor(
                        index: sample.index, count: count, center: center, rimRadius: rimRadius
                    )))
                }
                context.stroke(
                    lines,
                    with: .color(side == .drive ? AnodisedInk.driveTeal : AnodisedInk.nonDriveTeal),
                    style: side == .drive
                        ? StrokeStyle(lineWidth: 2 * weight, lineCap: .round)
                        : StrokeStyle(lineWidth: 1.6 * weight)
                )
            }

            let outline = RimPolarGeometry.deviationPolygon(
                normalized: RimDeviationScale.normalized(samples: samples, lens: lens),
                center: center,
                referenceRadius: Ring.outline * unit,
                span: Ring.swing * unit
            )
            if let first = outline.first, outline.count >= 3 {
                var polygon = Path()
                polygon.move(to: screen(first))
                for vertex in outline.dropFirst() { polygon.addLine(to: screen(vertex)) }
                polygon.closeSubpath()
                context.stroke(
                    polygon,
                    with: .color(AnodisedInk.rimGold),
                    style: StrokeStyle(lineWidth: 1.5 * weight, lineJoin: .round)
                )
            }

            if let selected, let sample = samples.first(where: { $0.index == selected }) {
                var marker = Path()
                marker.move(to: screen(RimPolarGeometry.hubAnchor(
                    index: selected, count: count, cross: cross,
                    side: sample.side, center: center, hubRadius: hubRadius
                )))
                let seat = RimPolarGeometry.rimAnchor(
                    index: selected, count: count, center: center, rimRadius: rimRadius
                )
                marker.addLine(to: screen(seat))
                context.stroke(marker, with: .color(AnodisedInk.rimGold),
                               style: StrokeStyle(lineWidth: 2.4 * weight, lineCap: .round))
                context.fill(disc(at: seat, radius: 5 * unit), with: .color(AnodisedInk.rimGold))
            }

            context.fill(disc(at: center, radius: Ring.hubDot * unit), with: .color(AnodisedInk.driveTeal))
        }
    }

    private func stroke(
        _ context: inout GraphicsContext,
        radius: Double,
        center: RimPoint,
        color: Color,
        style: StrokeStyle
    ) {
        context.stroke(Path(ellipseIn: box(center: center, radius: radius)), with: .color(color), style: style)
    }

    private func disc(at center: RimPoint, radius: Double) -> Path {
        Path(ellipseIn: box(center: center, radius: radius))
    }

    private func box(center: RimPoint, radius: Double) -> CGRect {
        CGRect(
            x: CGFloat(center.x - radius),
            y: CGFloat(center.y - radius),
            width: CGFloat(radius * 2),
            height: CGFloat(radius * 2)
        )
    }

    private func screen(_ rim: RimPoint) -> CGPoint {
        CGPoint(x: CGFloat(rim.x), y: CGFloat(rim.y))
    }
}
