import Foundation

/// The spoke the builder tapped, carried into the dial.
struct SpokeDialTarget: Identifiable, Hashable {
    let id: Int
    let side: SpokeSide
    let start: Double
}

@MainActor
final class RimMapModel: ObservableObject {
    @Published private(set) var wheels: [SpokeWheel] = []
    @Published private(set) var artefact: RimArtefact?
    @Published private(set) var failure: String?
    @Published var selectedWheelId: UUID?
    @Published var lens: RimLens = .tension
    @Published var dialTarget: SpokeDialTarget?

    private let container: SpokeContainer

    init(container: SpokeContainer) {
        self.container = container
    }

    var samples: [RimSample] { artefact?.samples ?? [] }
    var title: String { artefact?.title ?? "Spokewise" }
    var readout: RimReadout { artefact?.readout ?? RimReadout(meanKgf: 0, spreadPercent: 0, dishMm: 0) }

    /// Peak deviation the polygon's swing is currently worth.
    var deviationScale: String {
        let peak = RimDeviationScale.peak(samples: samples, lens: lens)
        guard peak > 0 else { return "Rim flat" }
        let value = lens == .tension ? String(format: "%.0f", peak) : String(format: "%.2f", peak)
        return "Rim ±\(value) \(lens.unit)"
    }

    func load() async {
        do {
            wheels = try await container.wheelRepository.fetchAll()
            let wanted = selectedWheelId ?? wheels.first?.id
            selectedWheelId = wanted
            guard let wanted else {
                artefact = nil
                return
            }
            artefact = try await container.loadArtefact(wheelId: wanted)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    func select(_ id: UUID) async {
        selectedWheelId = id
        await load()
    }

    /// Turn a tap on the map into the spoke the builder aimed at.
    func beginDial(at point: RimPoint, in size: CGSize) {
        let count = samples.count
        guard count > 0 else { return }
        let center = RimPoint(x: Double(size.width) / 2, y: Double(size.height) / 2)
        let index = RimPolarGeometry.nearestSpoke(to: point, center: center, count: count)
        guard let sample = artefact?.sample(at: index) else { return }
        let start = sample.dialValue(for: lens)
        dialTarget = SpokeDialTarget(
            id: index,
            side: sample.side,
            start: lens == .tension && !sample.isMeasured ? 24 : start
        )
    }

    func commit(_ value: Double) async {
        guard let target = dialTarget, let wheel = artefact?.wheel else { return }
        dialTarget = nil
        do {
            try await container.dialSpoke(
                wheelId: wheel.id,
                spokeCount: wheel.spokeCount,
                index: target.id,
                side: target.side,
                lens: lens,
                value: value
            )
            await load()
        } catch {
            failure = error.localizedDescription
        }
    }

    func dismissFailure() { failure = nil }
}
