import SwiftUI

/// The truing stand: the runout traced round the wheel. Drag on the ring to
/// dial the reading at that point of the rim, then log the pass.
struct TruingTraceView: View {
    let wheelId: UUID
    let container: SpokeContainer

    private enum Trace: Hashable {
        case lateral
        case radial
    }

    @State private var lateral: [Double] = []
    @State private var radial: [Double] = []
    @State private var editing: Trace = .lateral
    @State private var touched: Int?
    @State private var spokeCount = 32
    @State private var logged = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BenchChipRow(
                    options: [(Trace.lateral, "Lateral"), (Trace.radial, "Radial")],
                    selection: $editing
                )
                ring
                    .frame(height: 300)
                amplitudeReadout
                unrolled
                    .frame(height: 110)
                BenchCommit(title: logged ? "Pass logged" : "Log this pass") {
                    Task { await logPass() }
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Runout trace")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var active: [Double] { editing == .lateral ? lateral : radial }

    private var ring: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let base = Double(min(size.width, size.height)) * 0.32
                let gain = Double(min(size.width, size.height)) * 0.16

                context.stroke(
                    .rimRing(center: center, radius: base),
                    with: .color(AnodisedInk.rimHairline),
                    style: StrokeStyle(lineWidth: 1)
                )
                for offset in [-0.5, 0.5] {
                    context.stroke(
                        .rimRing(center: center, radius: base + offset * gain),
                        with: .color(AnodisedInk.innerHairline),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                    )
                }

                trace(&context, samples: lateral, center: center, base: base, gain: gain,
                      colour: AnodisedInk.driveTeal, emphasised: editing == .lateral)
                trace(&context, samples: radial, center: center, base: base, gain: gain,
                      colour: AnodisedInk.rimGold, emphasised: editing == .radial)

                if let touched, touched < active.count {
                    let angle = RimPolarGeometry.spokeAngle(index: touched, count: active.count)
                    let reach = base
                        + min(1, max(-1, active[touched] / Self.fullDeflectionMm)) * gain
                    let landing = CGPoint(
                        x: center.x + CGFloat(cos(angle) * reach),
                        y: center.y + CGFloat(sin(angle) * reach)
                    )
                    context.fill(.rimRing(center: landing, radius: 5), with: .color(AnodisedInk.readable))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in adjust(at: drag.location, in: proxy.size) }
                    .onEnded { _ in touched = nil }
            )
        }
    }

    private var unrolled: some View {
        Canvas { context, size in
            let points = RimProfileMath.profile(active, band: RimProfileMath.band([lateral, radial]))
            guard points.count >= 2 else { return }
            context.stroke(
                .rimTrail([RimPoint(x: 0, y: 0.5), RimPoint(x: 1, y: 0.5)], in: size),
                with: .color(AnodisedInk.innerHairline),
                style: StrokeStyle(lineWidth: 1)
            )
            context.stroke(
                .rimTrail(points, in: size),
                with: .color(editing == .lateral ? AnodisedInk.driveTeal : AnodisedInk.rimGold),
                style: StrokeStyle(lineWidth: 1.8, lineJoin: .round)
            )
        }
    }

    private var amplitudeReadout: some View {
        HStack(alignment: .top, spacing: 12) {
            figure("Lateral", String(format: "%.2f mm", SpokeMath.runoutAmplitude(samples: lateral)))
            Spacer(minLength: 0)
            figure("Radial", String(format: "%.2f mm", SpokeMath.runoutAmplitude(samples: radial)))
            Spacer(minLength: 0)
            figure("Hop", String(format: "%.2f mm", SpokeMath.firstHarmonicAmplitude(samples: radial)))
        }
    }

    private func figure(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption).rimCaption()
            Text(value)
                .font(RimFace.gauge(19))
                .foregroundStyle(AnodisedInk.driveTeal)
        }
    }

    private func trace(
        _ context: inout GraphicsContext,
        samples: [Double],
        center: CGPoint,
        base: Double,
        gain: Double,
        colour: Color,
        emphasised: Bool
    ) {
        context.stroke(
            .rimLoop(samples, center: center, base: base, gain: gain, scale: Self.fullDeflectionMm),
            with: .color(emphasised ? colour : colour.opacity(0.3)),
            style: StrokeStyle(lineWidth: emphasised ? 2 : 1.2, lineJoin: .round)
        )
    }

    /// Millimetres of runout that fill the ring's gain from centre to edge.
    private static let fullDeflectionMm: Double = 1.5

    private func adjust(at location: CGPoint, in size: CGSize) {
        let count = active.count
        guard count > 0 else { return }
        let center = RimPoint(x: Double(size.width) / 2, y: Double(size.height) / 2)
        let point = RimPoint(x: Double(location.x), y: Double(location.y))
        let index = RimPolarGeometry.nearestSpoke(to: point, center: center, count: count)
        let dialled = RimPolarGeometry.runout(
            reach: hypot(point.x - center.x, point.y - center.y),
            base: Double(min(size.width, size.height)) * 0.32,
            gain: Double(min(size.width, size.height)) * 0.16,
            fullScale: Self.fullDeflectionMm,
            step: 0.05
        )
        touched = index
        logged = false
        if editing == .lateral { lateral[index] = dialled } else { radial[index] = dialled }
    }

    private func load() async {
        if let wheel = try? await container.wheelRepository.fetch(id: wheelId) {
            spokeCount = wheel.spokeCount
        }
        let passes = (try? await container.truingRepository.fetch(wheelId: wheelId)) ?? []
        let latest = passes.last
        lateral = RimPolarGeometry.resample(latest?.lateralSamples ?? [], to: spokeCount)
        radial = RimPolarGeometry.resample(latest?.radialSamples ?? [], to: spokeCount)
    }

    private func logPass() async {
        try? await container.truingRepository.save(
            SpokeTruingPass(
                wheelId: wheelId,
                lateralCSV: RimPolarGeometry.csv(lateral),
                radialCSV: RimPolarGeometry.csv(radial)
            )
        )
        logged = true
    }
}
