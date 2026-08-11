import SwiftUI

/// Two wheels' tension profiles laid over one another, hole by hole, so the
/// difference between builds is one shape against another.
struct WheelOverlayView: View {
    let container: SpokeContainer

    @State private var artefacts: [RimArtefact] = []
    @State private var leftId: UUID?
    @State private var rightId: UUID?

    private var left: RimArtefact? { artefacts.first { $0.wheel.id == leftId } }
    private var right: RimArtefact? { artefacts.first { $0.wheel.id == rightId } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if artefacts.count < 2 {
                    Text("Two wheels are needed to overlay a profile.")
                        .font(RimFace.label(14))
                        .foregroundStyle(AnodisedInk.dimmed(0.7))
                } else {
                    picker(caption: "Front trace", selection: $leftId)
                    picker(caption: "Rear trace", selection: $rightId)
                    overlay
                        .frame(height: 260)
                    legend
                    deltaReadout
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Overlay")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func picker(caption: String, selection: Binding<UUID?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption).rimCaption()
            BenchChipRow(
                options: artefacts.map { ($0.wheel.id, $0.title) },
                selection: Binding(
                    get: { selection.wrappedValue ?? artefacts.first?.wheel.id ?? UUID() },
                    set: { selection.wrappedValue = $0 }
                )
            )
        }
    }

    private var overlay: some View {
        Canvas { context, size in
            let seriesA = left?.samples.map(\.tensionKgf) ?? []
            let seriesB = right?.samples.map(\.tensionKgf) ?? []
            let band = RimProfileMath.band([seriesA, seriesB])

            var grid = Path()
            for step in 1..<4 {
                let y = size.height * CGFloat(step) / 4
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(AnodisedInk.innerHairline), style: StrokeStyle(lineWidth: 1))
            context.stroke(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(AnodisedInk.rimHairline),
                style: StrokeStyle(lineWidth: 1)
            )

            plot(&context, series: seriesA, band: band, size: size, colour: AnodisedInk.driveTeal, width: 2)
            plot(&context, series: seriesB, band: band, size: size, colour: AnodisedInk.rimGold, width: 1.6)
        }
    }

    private func plot(
        _ context: inout GraphicsContext,
        series: [Double],
        band: ClosedRange<Double>,
        size: CGSize,
        colour: Color,
        width: CGFloat
    ) {
        let points = RimProfileMath.profile(series, band: band)
        guard points.count >= 2 else { return }
        context.stroke(
            .rimTrail(points, in: size),
            with: .color(colour),
            style: StrokeStyle(lineWidth: width, lineJoin: .round)
        )
    }

    private var legend: some View {
        HStack(spacing: 18) {
            swatch(AnodisedInk.driveTeal, left?.title ?? "—")
            swatch(AnodisedInk.rimGold, right?.title ?? "—")
            Spacer(minLength: 0)
        }
    }

    private func swatch(_ colour: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Capsule(style: .circular)
                .fill(colour)
                .frame(width: 14, height: 2)
            Text(title)
                .font(RimFace.label(11))
                .foregroundStyle(AnodisedInk.dimmed(0.7))
        }
    }

    private var deltaReadout: some View {
        HStack(alignment: .top, spacing: 12) {
            figure("Mean Δ", String(format: "%+.0f kgf", (left?.readout.meanKgf ?? 0) - (right?.readout.meanKgf ?? 0)))
            Spacer(minLength: 0)
            figure("Spread Δ", String(format: "%+.1f %%", (left?.readout.spreadPercent ?? 0) - (right?.readout.spreadPercent ?? 0)))
            Spacer(minLength: 0)
            figure("Dish Δ", String(format: "%+.1f mm", (left?.readout.dishMm ?? 0) - (right?.readout.dishMm ?? 0)))
        }
    }

    private func figure(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption).rimCaption()
            Text(value)
                .font(RimFace.gauge(18))
                .foregroundStyle(AnodisedInk.driveTeal)
        }
    }

    private func load() async {
        artefacts = (try? await container.loadThumbnails()) ?? []
        leftId = artefacts.first?.wheel.id
        rightId = artefacts.dropFirst().first?.wheel.id
    }
}
