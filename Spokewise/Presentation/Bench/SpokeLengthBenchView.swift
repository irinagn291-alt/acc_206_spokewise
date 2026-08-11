import SwiftUI

/// The length calculation drawn as the triangle a builder sketches: axle,
/// flange hole, nipple seat, then the offset folded in as the second leg.
struct SpokeLengthBenchView: View {
    let wheel: SpokeWheel?

    @State private var erd: Double = 565
    @State private var flange: Double = 58
    @State private var offset: Double = 34
    @State private var hole: Double = 2.6
    @State private var count: Int = 32
    @State private var cross: Int = 3

    private var triangle: SpokeTriangle {
        SpokeTriangleMath.triangle(
            erdMm: erd, flangeDiameterMm: flange, offsetMm: offset,
            holeMm: hole, spokeCount: count, cross: cross
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SpokeTriangleDiagram(triangle: triangle, cross: cross)
                    .frame(height: 250)
                lengthReadout
                VStack(alignment: .leading, spacing: 14) {
                    BenchDimension(caption: "Rim ERD", unit: "mm", range: 300...700, step: 0.5, decimals: 1, value: $erd)
                    BenchDimension(caption: "Flange diameter", unit: "mm", range: 30...110, step: 0.5, decimals: 1, value: $flange)
                    BenchDimension(caption: "Flange offset", unit: "mm", range: 5...45, step: 0.5, decimals: 1, value: $offset)
                    BenchDimension(caption: "Nipple seat", unit: "mm", range: 1.5...4, step: 0.1, decimals: 1, value: $hole)
                    BenchCount(caption: "Spoke holes", range: 16...48, value: $count)
                    BenchCount(caption: "Cross", range: 0...4, value: $cross)
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Spoke length")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: adoptWheel)
    }

    private var lengthReadout: some View {
        HStack(alignment: .top, spacing: 12) {
            figure("Length", String(format: "%.1f mm", triangle.lengthMm))
            Spacer(minLength: 0)
            figure("Chord", String(format: "%.1f mm", triangle.chordMm))
            Spacer(minLength: 0)
            figure("Wrap", String(format: "%.0f°", triangle.flangeAngle * 180 / .pi))
        }
    }

    private func figure(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption).rimCaption()
            Text(value)
                .font(RimFace.gauge(21))
                .tracking(-0.42)
                .foregroundStyle(AnodisedInk.driveTeal)
        }
    }

    private func adoptWheel() {
        guard let wheel else { return }
        erd = wheel.erdMm
        flange = wheel.flangeDiameterMm
        offset = wheel.rightOffsetMm
        hole = wheel.holeMm
        count = wheel.spokeCount
        cross = wheel.cross
    }
}

/// Face-on wheel with the spoke chord marked, and the right triangle that
/// turns that chord plus the flange offset into a cut length.
private struct SpokeTriangleDiagram: View {
    let triangle: SpokeTriangle
    let cross: Int

    var body: some View {
        Canvas { context, size in
            let plan = CGRect(x: 0, y: 0, width: size.width * 0.52, height: size.height)
            let elevation = CGRect(
                x: size.width * 0.56, y: 0,
                width: size.width * 0.44, height: size.height
            )
            drawPlan(&context, in: plan)
            drawElevation(&context, in: elevation)
        }
    }

    private func drawPlan(_ context: inout GraphicsContext, in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rimRadius = Double(min(rect.width, rect.height)) * 0.42
        let scale = rimRadius / max(triangle.rimSeat.x, 1)
        let flangeRadius = hypot(triangle.flangeHole.x, triangle.flangeHole.y) * scale

        context.stroke(
            circle(center: center, radius: rimRadius),
            with: .color(AnodisedInk.rimHairline),
            style: StrokeStyle(lineWidth: 1)
        )
        context.stroke(
            circle(center: center, radius: flangeRadius),
            with: .color(AnodisedInk.hubRing),
            style: StrokeStyle(lineWidth: 1.5)
        )

        let seat = CGPoint(x: center.x + CGFloat(triangle.rimSeat.x * scale), y: center.y)
        let flangeHole = CGPoint(
            x: center.x + CGFloat(triangle.flangeHole.x * scale),
            y: center.y + CGFloat(triangle.flangeHole.y * scale)
        )

        var radii = Path()
        radii.move(to: center)
        radii.addLine(to: seat)
        radii.move(to: center)
        radii.addLine(to: flangeHole)
        context.stroke(
            radii,
            with: .color(AnodisedInk.innerHairline),
            style: StrokeStyle(lineWidth: 1, dash: [3, 4])
        )

        var chord = Path()
        chord.move(to: flangeHole)
        chord.addLine(to: seat)
        context.stroke(
            chord,
            with: .color(AnodisedInk.driveTeal),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        context.fill(dot(at: seat, radius: 3.5), with: .color(AnodisedInk.rimGold))
        context.fill(dot(at: flangeHole, radius: 3.5), with: .color(AnodisedInk.driveTeal))
        context.fill(dot(at: center, radius: 3), with: .color(AnodisedInk.hubRing))

        label(&context, "\(cross)x", at: CGPoint(x: rect.midX, y: rect.maxY - 12), dimmed: true)
    }

    private func drawElevation(_ context: inout GraphicsContext, in rect: CGRect) {
        let inset: CGFloat = 26
        let base = CGPoint(x: rect.minX + inset, y: rect.maxY - inset - 24)
        let chordSpan = Double(rect.width - inset * 2)
        let offsetLeg = triangle.chordMm > 0
            ? chordSpan * (sqrt(max(0, pow(triangle.lengthMm, 2) - pow(triangle.chordMm, 2))) / triangle.chordMm)
            : 0
        let apex = CGPoint(x: base.x + CGFloat(chordSpan), y: base.y)
        let top = CGPoint(x: base.x, y: base.y - CGFloat(min(offsetLeg, Double(rect.height) - Double(inset) * 2)))

        var legs = Path()
        legs.move(to: top)
        legs.addLine(to: base)
        legs.addLine(to: apex)
        context.stroke(legs, with: .color(AnodisedInk.hubRing), style: StrokeStyle(lineWidth: 1.5))

        var hypotenuse = Path()
        hypotenuse.move(to: top)
        hypotenuse.addLine(to: apex)
        context.stroke(
            hypotenuse,
            with: .color(AnodisedInk.rimGold),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        label(&context, "chord", at: CGPoint(x: (base.x + apex.x) / 2, y: base.y + 12), dimmed: true)
        label(&context, "offset", at: CGPoint(x: base.x + 22, y: (base.y + top.y) / 2), dimmed: true)
        label(
            &context,
            String(format: "%.1f", triangle.lengthMm),
            at: CGPoint(x: (top.x + apex.x) / 2 + 8, y: (top.y + apex.y) / 2 - 12),
            dimmed: false
        )
    }

    private func label(_ context: inout GraphicsContext, _ text: String, at point: CGPoint, dimmed: Bool) {
        context.draw(
            Text(text)
                .font(RimFace.gauge(9))
                .foregroundStyle(dimmed ? AnodisedInk.dimmed(0.45) : AnodisedInk.rimGold),
            at: point
        )
    }

    private func circle(center: CGPoint, radius: Double) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - CGFloat(radius), y: center.y - CGFloat(radius),
            width: CGFloat(radius * 2), height: CGFloat(radius * 2)
        ))
    }

    private func dot(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
}
