import SwiftUI

/// Primary data entry: the spoke tapped on the map, dialled by dragging round
/// the ring. No typing, no row of fields.
struct SpokeDialSheet: View {
    let target: SpokeDialTarget
    let lens: RimLens
    let calibration: [(Double, Double)]
    let onCommit: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(
        target: SpokeDialTarget,
        lens: RimLens,
        calibration: [(Double, Double)],
        onCommit: @escaping (Double) -> Void
    ) {
        self.target = target
        self.lens = lens
        self.calibration = calibration
        self.onCommit = onCommit
        _value = State(initialValue: min(lens.dialRange.upperBound, max(lens.dialRange.lowerBound, target.start)))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            dial
                .frame(height: 244)
                .padding(.top, 4)
            fineRow
                .padding(.top, 6)
            Spacer(minLength: 12)
            commitButton
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .rimBackdrop()
        .presentationDetents([.height(468)])
        .presentationBackground(AnodisedInk.graphite)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Hole \(target.id) · \(target.side == .drive ? "drive" : "non-drive")")
                .font(RimFace.heading(17))
                .foregroundStyle(AnodisedInk.readable)
            Text(lens.dialCaption).rimCaption()
        }
        .padding(.top, 22)
    }

    private var dial: some View {
        GeometryReader { proxy in
            let center = RimPoint(x: Double(proxy.size.width) / 2, y: Double(proxy.size.height) / 2)
            ZStack {
                SpokeDialRing(fraction: SpokeDialMath.fraction(forValue: value, range: lens.dialRange))
                VStack(spacing: 2) {
                    Text(primaryReading)
                        .font(RimFace.gauge(34))
                        .tracking(-0.7)
                        .foregroundStyle(AnodisedInk.driveTeal)
                    Text(secondaryReading).rimCaption()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = SpokeDialMath.fraction(
                            at: RimPoint(x: Double(drag.location.x), y: Double(drag.location.y)),
                            center: center
                        )
                        value = SpokeDialMath.value(
                            forFraction: fraction,
                            range: lens.dialRange,
                            step: lens.dialStep
                        )
                    }
            )
        }
    }

    private var fineRow: some View {
        HStack(spacing: 18) {
            fineButton("minus", steps: -1)
            Text(lens.unit)
                .rimCaption()
                .frame(minWidth: 40)
            fineButton("plus", steps: 1)
        }
    }

    private func fineButton(_ symbol: String, steps: Int) -> some View {
        Button {
            value = SpokeDialMath.stepped(value, by: steps, range: lens.dialRange, step: lens.dialStep)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnodisedInk.readable)
                .frame(width: 42, height: 30)
                .overlay(
                    Capsule(style: .circular)
                        .strokeBorder(AnodisedInk.hubRing, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var commitButton: some View {
        Button {
            onCommit(value)
            dismiss()
        } label: {
            Text("Log spoke \(target.id)")
                .font(RimFace.chip(14, active: true))
                .tracking(0.5)
                .foregroundStyle(AnodisedInk.chipInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule(style: .circular).fill(AnodisedInk.driveTeal))
        }
        .buttonStyle(.plain)
    }

    private var primaryReading: String {
        switch lens {
        case .tension:
            return String(format: "%.0f", SpokeMath.kgf(deflection: value, table: calibration))
        case .dish, .trueness:
            return String(format: "%+.2f", value)
        }
    }

    private var secondaryReading: String {
        switch lens {
        case .tension: return String(format: "kgf · %.1f deflection", value)
        case .dish: return "mm lateral"
        case .trueness: return "mm radial"
        }
    }
}

/// The dial's track, its travelled arc, its tick marks and its knob.
private struct SpokeDialRing: View {
    let fraction: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = Double(min(size.width, size.height)) / 2 - 22

            context.stroke(
                arc(center: center, radius: radius, from: 0, to: 1),
                with: .color(AnodisedInk.hubRing),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            if fraction > 0.001 {
                context.stroke(
                    arc(center: center, radius: radius, from: 0, to: fraction),
                    with: .color(AnodisedInk.driveTeal),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
            }

            var ticks = Path()
            for step in 0...10 {
                let angle = SpokeDialMath.angle(forFraction: Double(step) / 10)
                let inner = radius + 10
                let outer = radius + 16
                ticks.move(to: CGPoint(
                    x: center.x + CGFloat(cos(angle) * inner),
                    y: center.y + CGFloat(sin(angle) * inner)
                ))
                ticks.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle) * outer),
                    y: center.y + CGFloat(sin(angle) * outer)
                ))
            }
            context.stroke(ticks, with: .color(AnodisedInk.rimHairline), style: StrokeStyle(lineWidth: 1))

            let knobAngle = SpokeDialMath.angle(forFraction: fraction)
            let knob = CGPoint(
                x: center.x + CGFloat(cos(knobAngle) * radius),
                y: center.y + CGFloat(sin(knobAngle) * radius)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: knob.x - 8, y: knob.y - 8, width: 16, height: 16)),
                with: .color(AnodisedInk.rimGold)
            )
        }
    }

    private func arc(center: CGPoint, radius: Double, from: Double, to: Double) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: CGFloat(radius),
            startAngle: .radians(SpokeDialMath.angle(forFraction: from)),
            endAngle: .radians(SpokeDialMath.angle(forFraction: to)),
            clockwise: false
        )
        return path
    }
}
