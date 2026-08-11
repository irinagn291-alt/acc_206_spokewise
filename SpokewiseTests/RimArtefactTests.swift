import XCTest
@testable import Spokewise

@MainActor
final class RimArtefactTests: XCTestCase {
    private var container: SpokeContainer!

    override func setUp() async throws {
        container = SpokeContainer(store: try SpokeSQLiteStore.inMemory())
    }

    private let table: [(Double, Double)] = [(15, 60), (20, 80), (25, 100), (30, 120)]

    func test_givenPartialReadings_whenBuilt_thenOneSamplePerHole() {
        let wheelId = UUID()
        let readings = [
            SpokeTensionReading(wheelId: wheelId, spokeIndex: 0, side: .drive, deflection: 25),
            SpokeTensionReading(wheelId: wheelId, spokeIndex: 1, side: .nonDrive, deflection: 20)
        ]
        let samples = RimArtefactBuilder.samples(
            spokeCount: 8, readings: readings, calibration: table, lateralTrace: [], radialTrace: []
        )
        XCTAssertEqual(samples.count, 8)
        XCTAssertEqual(samples.map(\.index), Array(0..<8))
    }

    func test_givenAReading_whenBuilt_thenTensionConvertedThroughTheTable() {
        let readings = [SpokeTensionReading(wheelId: UUID(), spokeIndex: 0, side: .drive, deflection: 25)]
        let samples = RimArtefactBuilder.samples(
            spokeCount: 4, readings: readings, calibration: table, lateralTrace: [], radialTrace: []
        )
        XCTAssertEqual(samples[0].tensionKgf, 100, accuracy: 0.01)
        XCTAssertTrue(samples[0].isMeasured)
    }

    func test_givenUnreadHole_whenBuilt_thenFilledWithTheWorkingMean() {
        let readings = [
            SpokeTensionReading(wheelId: UUID(), spokeIndex: 0, side: .drive, deflection: 25),
            SpokeTensionReading(wheelId: UUID(), spokeIndex: 1, side: .nonDrive, deflection: 20)
        ]
        let samples = RimArtefactBuilder.samples(
            spokeCount: 4, readings: readings, calibration: table, lateralTrace: [], radialTrace: []
        )
        XCTAssertFalse(samples[2].isMeasured)
        XCTAssertEqual(samples[2].tensionKgf, 90, accuracy: 0.01)
    }

    func test_givenUnreadHole_whenBuilt_thenSideFollowsTheLacing() {
        let samples = RimArtefactBuilder.samples(
            spokeCount: 4, readings: [], calibration: table, lateralTrace: [], radialTrace: []
        )
        XCTAssertEqual(samples.map(\.side), [.drive, .nonDrive, .drive, .nonDrive])
    }

    func test_givenShortRunoutTrace_whenBuilt_thenStretchedOverEveryHole() {
        let samples = RimArtefactBuilder.samples(
            spokeCount: 8, readings: [], calibration: table,
            lateralTrace: [1, 2], radialTrace: [0.2, 0.4]
        )
        XCTAssertEqual(samples[0].lateralMm, 1, accuracy: 0.0001)
        XCTAssertEqual(samples[4].lateralMm, 2, accuracy: 0.0001)
        XCTAssertEqual(samples.count, 8)
    }

    func test_givenLens_whenSampleDialled_thenOffersThatLensValue() {
        let sample = RimSample(
            index: 3, side: .drive, tensionKgf: 100, deflection: 25,
            lateralMm: 0.4, radialMm: -0.2, isMeasured: true
        )
        XCTAssertEqual(sample.dialValue(for: .tension), 25, accuracy: 0.0001)
        XCTAssertEqual(sample.dialValue(for: .dish), 0.4, accuracy: 0.0001)
        XCTAssertEqual(sample.dialValue(for: .trueness), -0.2, accuracy: 0.0001)
    }

    func test_givenSeededWorkshop_whenArtefactLoaded_thenOneSamplePerHole() async throws {
        try await container.seeder.seedIfEmpty()
        let wheel = try await firstWheel()
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        XCTAssertEqual(artefact.samples.count, wheel.spokeCount)
        XCTAssertEqual(artefact.title, "Rear · 32h")
    }

    func test_givenSeededWorkshop_whenArtefactLoaded_thenDishReadsTheOffsetPlane() async throws {
        try await container.seeder.seedIfEmpty()
        let artefact = try await container.loadArtefact(wheelId: try await firstWheel().id)
        XCTAssertEqual(artefact.readout.dishMm, 2.1, accuracy: 0.15)
        XCTAssertGreaterThan(artefact.readout.meanKgf, 0)
        XCTAssertGreaterThan(artefact.readout.spreadPercent, 0)
    }

    func test_givenMissingWheel_whenArtefactLoaded_thenNotFound() async {
        do {
            _ = try await container.loadArtefact(wheelId: UUID())
            XCTFail("Expected a missing wheel to be reported")
        } catch {
            XCTAssertTrue(error is SpokeStoreError)
        }
    }

    func test_givenSeededWorkshop_whenSpokeDialledOnTension_thenReadingMoves() async throws {
        try await container.seeder.seedIfEmpty()
        let wheel = try await firstWheel()
        try await container.dialSpoke(
            wheelId: wheel.id, spokeCount: wheel.spokeCount, index: 5,
            side: .nonDrive, lens: .tension, value: 30
        )
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        XCTAssertEqual(artefact.sample(at: 5)?.deflection, 30)
        XCTAssertEqual(artefact.sample(at: 5)?.tensionKgf ?? 0, 120, accuracy: 0.01)
    }

    func test_givenSeededWorkshop_whenSpokeDialledOnDish_thenLateralMoves() async throws {
        try await container.seeder.seedIfEmpty()
        let wheel = try await firstWheel()
        try await container.dialSpoke(
            wheelId: wheel.id, spokeCount: wheel.spokeCount, index: 9,
            side: .nonDrive, lens: .dish, value: -1.25
        )
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        XCTAssertEqual(artefact.sample(at: 9)?.lateralMm ?? 0, -1.25, accuracy: 0.01)
    }

    func test_givenSeededWorkshop_whenSpokeDialledOnTrue_thenRadialMoves() async throws {
        try await container.seeder.seedIfEmpty()
        let wheel = try await firstWheel()
        try await container.dialSpoke(
            wheelId: wheel.id, spokeCount: wheel.spokeCount, index: 11,
            side: .drive, lens: .trueness, value: 0.75
        )
        let artefact = try await container.loadArtefact(wheelId: wheel.id)
        XCTAssertEqual(artefact.sample(at: 11)?.radialMm ?? 0, 0.75, accuracy: 0.01)
    }

    func test_givenHoleOffTheWheel_whenDialled_thenNothingIsWritten() async throws {
        try await container.seeder.seedIfEmpty()
        let wheel = try await firstWheel()
        let before = try await container.loadArtefact(wheelId: wheel.id)
        try await container.dialSpoke(
            wheelId: wheel.id, spokeCount: wheel.spokeCount, index: 99,
            side: .drive, lens: .tension, value: 12
        )
        let after = try await container.loadArtefact(wheelId: wheel.id)
        XCTAssertEqual(before.samples.count, after.samples.count)
        XCTAssertEqual(before.readout.meanKgf, after.readout.meanKgf, accuracy: 0.0001)
    }

    func test_givenSeededWorkshop_whenThumbnailsLoaded_thenEveryWheelIsDrawable() async throws {
        try await container.seeder.seedIfEmpty()
        let artefacts = try await container.loadThumbnails()
        XCTAssertGreaterThanOrEqual(artefacts.count, 3)
        for artefact in artefacts {
            XCTAssertEqual(artefact.samples.count, artefact.wheel.spokeCount)
        }
    }

    private func firstWheel() async throws -> SpokeWheel {
        guard let wheel = try await container.wheelRepository.fetchAll().first else {
            throw SpokeStoreError.notFound
        }
        return wheel
    }
}
