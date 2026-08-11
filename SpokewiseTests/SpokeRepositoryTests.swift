import XCTest
@testable import Spokewise

@MainActor
final class SpokeRepositoryTests: XCTestCase {
    private var store: SpokeSQLiteStore!
    private var container: SpokeContainer!

    override func setUp() async throws {
        store = try SpokeSQLiteStore.inMemory()
        container = SpokeContainer(store: store)
    }

    func test_givenWheel_whenSaved_thenFetched() async throws {
        let w = SpokeWheel(name: "Test", erdMm: 560, flangeDiameterMm: 55, leftOffsetMm: 20, rightOffsetMm: 30)
        try await container.wheelRepository.save(w)
        let fetched = try await container.wheelRepository.fetch(id: w.id)
        XCTAssertEqual(fetched?.name, "Test")
    }

    func test_givenWheel_whenDeleted_thenMissing() async throws {
        let w = SpokeWheel(name: "X", erdMm: 560, flangeDiameterMm: 55, leftOffsetMm: 20, rightOffsetMm: 30)
        try await container.wheelRepository.save(w)
        try await container.wheelRepository.delete(id: w.id)
        let fetched = try await container.wheelRepository.fetch(id: w.id)
        XCTAssertNil(fetched)
    }

    func test_givenComponent_whenSaved_thenListed() async throws {
        try await container.componentRepository.save(SpokeComponent(kind: "rim", name: "R1", erdMm: 570))
        let all = try await container.componentRepository.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func test_givenTension_whenSaved_thenFetchedForWheel() async throws {
        let id = UUID()
        try await container.tensionRepository.save(SpokeTensionReading(wheelId: id, spokeIndex: 3, side: .drive, deflection: 24))
        let list = try await container.tensionRepository.fetch(wheelId: id)
        XCTAssertEqual(list.first?.spokeIndex, 3)
    }

    func test_givenTension_whenDeleted_thenGone() async throws {
        let r = SpokeTensionReading(wheelId: UUID(), spokeIndex: 1, side: .drive, deflection: 22)
        try await container.tensionRepository.save(r)
        try await container.tensionRepository.delete(id: r.id)
        let list = try await container.tensionRepository.fetch(wheelId: r.wheelId)
        XCTAssertTrue(list.isEmpty)
    }

    func test_givenTruingPass_whenSaved_thenSamplesParse() async throws {
        let id = UUID()
        try await container.truingRepository.save(SpokeTruingPass(wheelId: id, lateralCSV: "0.1,0.2", radialCSV: "0,0.1"))
        let pass = try await container.truingRepository.fetch(wheelId: id).first
        XCTAssertEqual(pass?.lateralSamples.count, 2)
    }

    func test_givenBuild_whenSaved_thenInHistory() async throws {
        let id = UUID()
        try await container.buildRepository.save(SpokeBuild(wheelId: id, startedAt: Date(), finishedAt: Date(), notes: "lace"))
        let list = try await container.buildRepository.fetch(wheelId: id)
        XCTAssertEqual(list.count, 1)
    }

    func test_givenCalibration_whenSaved_thenPairs() async throws {
        try await container.calibrationRepository.save(SpokeCalibration(toolName: "T", gauge: "2.0", deflectionCSV: "20,30", kgfCSV: "80,120"))
        let pairs = try await container.calibrationRepository.fetchAll().first?.pairs
        XCTAssertEqual(pairs?.count, 2)
    }

    func test_givenMileage_whenSaved_thenFetched() async throws {
        let id = UUID()
        try await container.mileageRepository.save(SpokeMileageEntry(wheelId: id, date: Date(), km: 250))
        let list = try await container.mileageRepository.fetch(wheelId: id)
        XCTAssertEqual(list.first?.km, 250)
    }

    func test_givenService_whenSaved_thenListed() async throws {
        try await container.serviceRepository.save(SpokeServiceEvent(wheelId: UUID(), date: Date(), title: "True"))
        let all = try await container.serviceRepository.fetchAll()
        XCTAssertFalse(all.isEmpty)
    }

    func test_givenSettings_whenSaved_thenPersisted() async throws {
        var s = try await container.settingsRepository.load()
        s.preferredGauge = "1.8"
        try await container.settingsRepository.save(s)
        let loaded = try await container.settingsRepository.load()
        XCTAssertEqual(loaded.preferredGauge, "1.8")
    }

    func test_givenEmpty_whenSeeded_thenWheelsExist() async throws {
        try await container.seeder.seedIfEmpty()
        let wheels = try await container.wheelRepository.fetchAll()
        XCTAssertGreaterThanOrEqual(wheels.count, 3)
    }

    func test_givenSeed_whenOutOfTolerance_thenPresent() async throws {
        try await container.seeder.seedIfEmpty()
        let wheels = try await container.wheelRepository.fetchAll()
        let table = try await container.calibrationRepository.fetchAll().first!.pairs
        var found = false
        for w in wheels {
            let readings = try await container.tensionRepository.fetch(wheelId: w.id)
            if readings.contains(where: { SpokeMath.kgf(deflection: $0.deflection, table: table) < 75 }) { found = true }
        }
        XCTAssertTrue(found)
    }

    func test_givenSeed_whenExportCSV_thenHeader() async throws {
        try await container.seeder.seedIfEmpty()
        let id = try await container.wheelRepository.fetchAll().first!.id
        let csv = try await container.exportCSV(wheelId: id)
        XCTAssertTrue(csv.contains("spoke_index,side,deflection,kgf"))
    }

    func test_givenSeed_whenStats_thenMetrics() async throws {
        try await container.seeder.seedIfEmpty()
        let stats = try await container.loadStats()
        XCTAssertFalse(stats.tensionSDHistory.isEmpty)
        XCTAssertEqual(stats.tensionByPosition.count, 32)
        XCTAssertGreaterThanOrEqual(stats.meanBuildHours, 0)
        XCTAssertGreaterThanOrEqual(stats.dishDriftMm, 0)
        XCTAssertGreaterThanOrEqual(stats.kmBetweenTruings, 0)
    }

    func test_givenSeedTwice_whenIdempotent_thenSameCount() async throws {
        try await container.seeder.seedIfEmpty()
        let c1 = try await container.wheelRepository.fetchAll().count
        try await container.seeder.seedIfEmpty()
        let c2 = try await container.wheelRepository.fetchAll().count
        XCTAssertEqual(c1, c2)
    }

    func test_givenReference_whenCounted_thenEighteen() {
        XCTAssertEqual(SpokeReferenceLibrary.entries.count, 18)
    }

    func test_givenComponentDelete_whenCalled_thenRemoved() async throws {
        let c = SpokeComponent(kind: "hub", name: "Temp")
        try await container.componentRepository.save(c)
        try await container.componentRepository.delete(id: c.id)
        let all = try await container.componentRepository.fetchAll()
        XCTAssertFalse(all.contains { $0.id == c.id })
    }

    func test_givenBundle_whenLoaded_thenIncludesTensions() async throws {
        try await container.seeder.seedIfEmpty()
        let id = try await container.wheelRepository.fetchAll().first!.id
        let bundle = try await container.loadBundle(wheelId: id)
        XCTAssertEqual(bundle.tensions.count, 32)
    }
}
