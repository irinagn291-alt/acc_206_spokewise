import SwiftUI
import XCTest
@testable import Spokewise

/// Renders every drawn surface once so a bad path, an empty artefact or an
/// out-of-range hole is caught here rather than on the stand.
@MainActor
final class RimRenderSmokeTests: XCTestCase {
    private var container: SpokeContainer!
    private var wheel: SpokeWheel!

    override func setUp() async throws {
        container = SpokeContainer(store: try SpokeSQLiteStore.inMemory())
        try await container.seeder.seedIfEmpty()
        wheel = try await container.wheelRepository.fetchAll().first
        XCTAssertNotNil(wheel)
    }

    func test_givenSeededWheel_whenMapRendered_thenEveryLensDraws() async throws {
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        for lens in RimLens.allCases {
            let map = RimMapCanvas(
                samples: artefact.samples,
                cross: artefact.wheel.cross,
                lens: lens,
                selected: 4
            )
            XCTAssertNotNil(render(map, size: CGSize(width: 380, height: 380)))
        }
    }

    func test_givenNoReadings_whenMapRendered_thenStillDraws() {
        let map = RimMapCanvas(samples: [], cross: 3, lens: .tension)
        XCTAssertNotNil(render(map, size: CGSize(width: 380, height: 380)))
    }

    func test_givenThumbnailWeight_whenMapRendered_thenDrawsSmall() async throws {
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        let map = RimMapCanvas(
            samples: artefact.samples, cross: artefact.wheel.cross, lens: .dish, weight: 0.6
        )
        XCTAssertNotNil(render(map, size: CGSize(width: 120, height: 120)))
    }

    func test_givenHeroShell_whenRendered_thenChipsAndReadoutDraw() async {
        let model = RimMapModel(container: container)
        await model.load()
        let hero = NavigationStack { RimMapScreen(model: model, path: .constant(NavigationPath())) }
        XCTAssertNotNil(render(hero, size: CGSize(width: 393, height: 852)))
    }

    func test_givenTappedSpoke_whenDialRendered_thenEveryLensDraws() async throws {
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        for lens in RimLens.allCases {
            let sheet = SpokeDialSheet(
                target: SpokeDialTarget(id: 3, side: .drive, start: artefact.samples[3].dialValue(for: lens)),
                lens: lens,
                calibration: artefact.calibration,
                onCommit: { _ in }
            )
            XCTAssertNotNil(render(sheet, size: CGSize(width: 393, height: 468)))
        }
    }

    func test_givenBenchScreens_whenRendered_thenDiagramsDraw() {
        XCTAssertNotNil(render(SpokeLengthBenchView(wheel: wheel), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(CalibrationCurveView(container: container), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(ComponentBenchView(container: container), size: CGSize(width: 393, height: 900)))
    }

    func test_givenWheelScreens_whenRendered_thenTracesDraw() {
        XCTAssertNotNil(render(TruingTraceView(wheelId: wheel.id, container: container), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(BuildLedgerView(container: container), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(WheelOverlayView(container: container), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(WheelStatisticsView(loadStats: container.loadStats), size: CGSize(width: 393, height: 900)))
    }

    func test_givenTabularScreens_whenRendered_thenListsDraw() {
        XCTAssertNotNil(render(LacingPatternIndexView(), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(ServiceLogView(container: container), size: CGSize(width: 393, height: 900)))
        XCTAssertNotNil(render(SpokeSettingsView(container: container), size: CGSize(width: 393, height: 900)))
    }

    private func render<Content: View>(_ view: Content, size: CGSize) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        return renderer.cgImage
    }
}
