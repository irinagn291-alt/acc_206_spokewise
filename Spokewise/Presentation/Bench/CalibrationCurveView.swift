import SwiftUI

/// The tensiometer table as the curve it really is. Drag a knot up or down to
/// re-fit the tool; the interpolated reading under the plot follows.
struct CalibrationCurveView: View {
    let container: SpokeContainer

    @State private var record: SpokeCalibration?
    @State private var knots: [(deflection: Double, kgf: Double)] = []
    @State private var dragging: Int?
    @State private var probe: Double = 24
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                plot
                    .frame(height: 260)
                probeReadout
                BenchDimension(
                    caption: "Probe deflection", unit: "mm",
                    range: CalibrationCurveMath.deflectionRange, step: 0.1, decimals: 1,
                    value: $probe
                )
                Text(record.map { "\($0.toolName) · \($0.gauge) mm gauge" } ?? "No tool on file")
                    .rimCaption()
                BenchCommit(title: saved ? "Curve saved" : "Save curve") {
                    Task { await save() }
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Tensiometer curve")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var plot: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawGrid(&context, size: size)
                let plotted = CalibrationCurveMath.plotted(knots)
                guard plotted.count >= 2 else { return }

                var curve = Path()
                curve.move(to: screen(plotted[0], in: size))
                for point in plotted.dropFirst() { curve.addLine(to: screen(point, in: size)) }
                context.stroke(
                    curve,
                    with: .color(AnodisedInk.driveTeal),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                for (index, point) in plotted.enumerated() {
                    let center = screen(point, in: size)
                    let radius: CGFloat = dragging == index ? 8 : 6
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(dragging == index ? AnodisedInk.rimGold : AnodisedInk.graphite)
                    )
                    context.stroke(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(AnodisedInk.rimGold),
                        style: StrokeStyle(lineWidth: 1.8)
                    )
                }

                let mark = CGPoint(
                    x: CGFloat(unit(probe, in: CalibrationCurveMath.deflectionRange)) * size.width,
                    y: 0
                )
                var probeLine = Path()
                probeLine.move(to: CGPoint(x: mark.x, y: 0))
                probeLine.addLine(to: CGPoint(x: mark.x, y: size.height))
                context.stroke(
                    probeLine,
                    with: .color(AnodisedInk.nonDriveTeal),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in handle(drag.location, in: proxy.size) }
                    .onEnded { _ in dragging = nil }
            )
        }
    }

    private var probeReadout: some View {
        HStack(alignment: .top, spacing: 12) {
            figure("Reads", String(format: "%.0f kgf", SpokeMath.kgf(deflection: probe, table: knots.map { ($0.deflection, $0.kgf) })))
            Spacer(minLength: 0)
            figure("Knots", "\(knots.count)")
            Spacer(minLength: 0)
            figure("Span", spanLabel)
        }
    }

    private var spanLabel: String {
        guard let low = knots.first?.kgf, let high = knots.last?.kgf else { return "—" }
        return String(format: "%.0f–%.0f", low, high)
    }

    private func figure(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption).rimCaption()
            Text(value)
                .font(RimFace.gauge(19))
                .foregroundStyle(AnodisedInk.driveTeal)
        }
    }

    private func handle(_ location: CGPoint, in size: CGSize) {
        guard !knots.isEmpty, size.width > 0, size.height > 0 else { return }
        let plotPoint = RimPoint(
            x: Double(location.x / size.width),
            y: Double(location.y / size.height)
        )
        let index = dragging ?? CalibrationCurveMath.nearestKnot(
            to: plotPoint,
            among: CalibrationCurveMath.plotted(knots)
        )
        guard let index else { return }
        dragging = index
        saved = false
        knots[index].kgf = CalibrationCurveMath.draggedKgf(plotY: plotPoint.y, index: index, in: knots)
    }

    private func drawGrid(_ context: inout GraphicsContext, size: CGSize) {
        var grid = Path()
        for step in 1..<5 {
            let y = size.height * CGFloat(step) / 5
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        for step in 1..<6 {
            let x = size.width * CGFloat(step) / 6
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(grid, with: .color(AnodisedInk.innerHairline), style: StrokeStyle(lineWidth: 1))
        context.stroke(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(AnodisedInk.rimHairline),
            style: StrokeStyle(lineWidth: 1)
        )
    }

    private func screen(_ point: RimPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
    }

    private func unit(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    private func load() async {
        record = try? await container.calibrationRepository.fetchAll().first
        let pairs = record?.pairs ?? [(15, 60), (20, 80), (25, 100), (30, 120)]
        knots = pairs.map { (deflection: $0.0, kgf: $0.1) }.sorted { $0.deflection < $1.deflection }
    }

    private func save() async {
        let columns = CalibrationCurveMath.columns(knots)
        let updated = SpokeCalibration(
            id: record?.id ?? UUID(),
            toolName: record?.toolName ?? "Park TM-1",
            gauge: record?.gauge ?? "2.0",
            deflectionCSV: columns.deflection,
            kgfCSV: columns.kgf
        )
        try? await container.calibrationRepository.save(updated)
        record = updated
        saved = true
    }
}
