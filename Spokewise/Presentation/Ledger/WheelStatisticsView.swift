import SwiftUI

/// Workshop-wide figures, each shown in the shape of the thing it measures.
struct WheelStatisticsView: View {
    let loadStats: LoadSpokeStatsUseCase

    @State private var stats: SpokeStatsSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats {
                    figures(stats)
                    section("Radial deviation") {
                        RadialDeviationRing(samples: stats.radialSamples)
                            .frame(height: 210)
                    }
                    section("Tension distribution") {
                        TensionBinStrip(bins: stats.tensionHistogram)
                            .frame(height: 150)
                    }
                    section("Tension by hole") {
                        HolePositionStrip(byPosition: stats.tensionByPosition)
                            .frame(height: 130)
                    }
                } else {
                    ProgressView().tint(AnodisedInk.driveTeal)
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .task { stats = try? await loadStats() }
    }

    private func section<Content: View>(_ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption).rimCaption()
            content()
        }
    }

    private func figures(_ stats: SpokeStatsSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            figure("SD", String(format: "%.1f", stats.tensionSDHistory.last ?? 0))
            Spacer(minLength: 0)
            figure("Build", String(format: "%.1f h", stats.meanBuildHours))
            Spacer(minLength: 0)
            figure("Drift", String(format: "%.1f mm", stats.dishDriftMm))
            Spacer(minLength: 0)
            figure("Km", String(format: "%.0f", stats.kmBetweenTruings))
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
}

/// Radial runout as a closed trace about the rim's nominal circle.
private struct RadialDeviationRing: View {
    let samples: [Double]

    var body: some View {
        Canvas { context, size in
            let count = samples.count
            guard count >= 3 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let base = Double(min(size.width, size.height)) * 0.3
            let gain = Double(min(size.width, size.height)) * 0.14
            let peak = max(samples.map { abs($0) }.max() ?? 1, 0.01)

            context.stroke(
                .rimRing(center: center, radius: base),
                with: .color(AnodisedInk.rimHairline),
                style: StrokeStyle(lineWidth: 1, dash: [3, 4])
            )
            context.stroke(
                .rimLoop(samples, center: center, base: base, gain: gain, scale: peak),
                with: .color(AnodisedInk.rimGold),
                style: StrokeStyle(lineWidth: 2, lineJoin: .round)
            )
        }
    }
}

/// How many spokes land in each tension band.
private struct TensionBinStrip: View {
    let bins: [Double]

    var body: some View {
        Canvas { context, size in
            guard !bins.isEmpty else { return }
            let peak = max(bins.max() ?? 1, 1)
            let gap: CGFloat = 5
            let width = (size.width - gap * CGFloat(bins.count - 1)) / CGFloat(bins.count)
            for (index, value) in bins.enumerated() {
                let height = CGFloat(value / peak) * (size.height - 6)
                let rect = CGRect(
                    x: CGFloat(index) * (width + gap),
                    y: size.height - height,
                    width: width,
                    height: height
                )
                context.fill(
                    Path(roundedRect: rect, cornerSize: CGSize(width: 2, height: 2)),
                    with: .color(index >= bins.count - 2 ? AnodisedInk.rimGold : AnodisedInk.nonDriveTeal)
                )
            }
        }
    }
}

/// Mean tension per hole around the rim, unrolled left to right.
private struct HolePositionStrip: View {
    let byPosition: [Double]

    var body: some View {
        Canvas { context, size in
            let band = RimProfileMath.band([byPosition])
            let points = RimProfileMath.profile(byPosition, band: band)
            guard points.count >= 2 else { return }

            let midline = [RimPoint(x: 0, y: 0.5), RimPoint(x: 1, y: 0.5)]
            context.stroke(
                .rimTrail(midline, in: size),
                with: .color(AnodisedInk.innerHairline),
                style: StrokeStyle(lineWidth: 1)
            )
            context.stroke(
                .rimTrail(points, in: size),
                with: .color(AnodisedInk.driveTeal),
                style: StrokeStyle(lineWidth: 1.8, lineJoin: .round)
            )
        }
    }
}
