import SwiftUI
import UIKit
import XCTest
@testable import Spokewise

@MainActor
final class TempShotTests: XCTestCase {
    func test_shots() async throws {
        let container = SpokeContainer(store: try SpokeSQLiteStore.inMemory())
        try await container.seeder.seedIfEmpty()
        let wheel = try await container.wheelRepository.fetchAll().first!
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
        print("SHOTDIR \(root.path)")

        for lens in RimLens.allCases {
            let model = RimMapModel(container: container)
            await model.load()
            model.lens = lens
            let hero = NavigationStack { RimMapScreen(model: model, path: .constant(NavigationPath())) }
            write(hero, size: CGSize(width: 393, height: 852), to: root.appendingPathComponent("hero-\(lens.rawValue).png"))
        }

        let dial = SpokeDialSheet(
            target: SpokeDialTarget(id: 7, side: .drive, start: 24),
            lens: .tension,
            calibration: artefact.calibration,
            onCommit: { _ in }
        )
        write(dial, size: CGSize(width: 393, height: 468), to: root.appendingPathComponent("dial.png"))

        write(
            SpokeLengthBenchView(wheel: wheel),
            size: CGSize(width: 393, height: 852),
            to: root.appendingPathComponent("bench.png")
        )
        write(
            CalibrationCurveView(container: container),
            size: CGSize(width: 393, height: 852),
            to: root.appendingPathComponent("curve.png")
        )
        write(
            TruingTraceView(wheelId: wheel.id, container: container),
            size: CGSize(width: 393, height: 852),
            to: root.appendingPathComponent("truing.png")
        )
        write(
            BuildLedgerView(container: container),
            size: CGSize(width: 393, height: 852),
            to: root.appendingPathComponent("ledger.png")
        )
        write(
            WheelOverlayView(container: container),
            size: CGSize(width: 393, height: 852),
            to: root.appendingPathComponent("overlay.png")
        )
        write(
            ComponentBenchView(container: container),
            size: CGSize(width: 393, height: 852),
            to: root.appendingPathComponent("parts.png")
        )
    }

    private func write<Content: View>(_ view: Content, size: CGSize, to url: URL) {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .background(AnodisedInk.graphite)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }
        let attachment = XCTAttachment(image: image)
        attachment.name = url.lastPathComponent
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
