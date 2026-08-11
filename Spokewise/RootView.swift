import SwiftUI

struct RootView: View {
    let container: SpokeContainer
    @State private var path = NavigationPath()
    @StateObject private var map: RimMapModel

    init(container: SpokeContainer) {
        self.container = container
        _map = StateObject(wrappedValue: RimMapModel(container: container))
    }

    var body: some View {
        NavigationStack(path: $path) {
            RimMapScreen(model: map, path: $path)
                .navigationDestination(for: SpokeRoute.self, destination: screen)
        }
        .tint(AnodisedInk.driveTeal)
        .preferredColorScheme(.dark)
        .task {
            try? await container.seeder.seedIfEmpty()
            await map.load()
        }
    }

    @ViewBuilder
    private func screen(for route: SpokeRoute) -> some View {
        switch route {
        case .bench: SpokeLengthBenchView(wheel: map.artefact?.wheel)
        case .components: ComponentBenchView(container: container)
        case .calibration: CalibrationCurveView(container: container)
        case .truing(let id): TruingTraceView(wheelId: id, container: container)
        case .builds: BuildLedgerView(container: container)
        case .stats: WheelStatisticsView(loadStats: container.loadStats)
        case .compare: WheelOverlayView(container: container)
        case .reference: LacingPatternIndexView()
        case .maintenance: ServiceLogView(container: container)
        case .settings: SpokeSettingsView(container: container)
        }
    }
}

#Preview { RootView(container: SpokeContainer.preview()) }
