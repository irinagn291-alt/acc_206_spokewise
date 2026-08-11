import SwiftUI

/// Past builds as small multiples: every wheel's polar map at thumbnail size,
/// so a drifting build is visible without opening anything.
struct BuildLedgerView: View {
    let container: SpokeContainer

    @State private var artefacts: [RimArtefact] = []
    @State private var builds: [UUID: SpokeBuild] = [:]
    @State private var lens: RimLens = .tension

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BenchChipRow(
                    options: RimLens.allCases.map { ($0, $0.title) },
                    selection: $lens
                )
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(artefacts, id: \.wheel.id) { artefact in
                        thumbnail(artefact)
                    }
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Build ledger")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func thumbnail(_ artefact: RimArtefact) -> some View {
        let figures = RimReadoutMath.format(artefact.readout)
        return VStack(alignment: .leading, spacing: 8) {
            RimMapCanvas(
                samples: artefact.samples,
                cross: artefact.wheel.cross,
                lens: lens,
                weight: 0.6
            )
            .aspectRatio(1, contentMode: .fit)
            Text(artefact.title)
                .font(RimFace.label(13))
                .foregroundStyle(AnodisedInk.readable)
            Text("\(figures.mean) · \(figures.spread)")
                .font(RimFace.gauge(11))
                .foregroundStyle(AnodisedInk.driveTeal)
            Text(hours(for: artefact.wheel.id))
                .rimCaption()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: RimRadius.tile, style: .continuous)
                .strokeBorder(AnodisedInk.rimHairline, lineWidth: 1)
        )
    }

    private func hours(for wheelId: UUID) -> String {
        guard let build = builds[wheelId] else { return "No build logged" }
        guard let finished = build.finishedAt else { return "On the stand" }
        return String(format: "%.1f h at the stand", finished.timeIntervalSince(build.startedAt) / 3600)
    }

    private func load() async {
        artefacts = (try? await container.loadThumbnails()) ?? []
        let all = (try? await container.buildRepository.fetchAll()) ?? []
        var latest: [UUID: SpokeBuild] = [:]
        for build in all where latest[build.wheelId] == nil {
            latest[build.wheelId] = build
        }
        builds = latest
    }
}
