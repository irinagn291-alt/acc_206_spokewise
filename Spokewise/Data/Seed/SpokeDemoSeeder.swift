import Foundation

/// Seeds three demo wheels with calibration, tensions and maintenance data.
public struct SpokeDemoSeeder: Sendable {
    private let wheels: SpokeWheelRepository
    private let components: SpokeComponentRepository
    private let tensions: SpokeTensionRepository
    private let truing: SpokeTruingRepository
    private let builds: SpokeBuildRepository
    private let calibration: SpokeCalibrationRepository
    private let mileage: SpokeMileageRepository
    private let services: SpokeServiceRepository
    private let settings: SpokeSettingsRepository

    public init(
        wheels: SpokeWheelRepository,
        components: SpokeComponentRepository,
        tensions: SpokeTensionRepository,
        truing: SpokeTruingRepository,
        builds: SpokeBuildRepository,
        calibration: SpokeCalibrationRepository,
        mileage: SpokeMileageRepository,
        services: SpokeServiceRepository,
        settings: SpokeSettingsRepository
    ) {
        self.wheels = wheels
        self.components = components
        self.tensions = tensions
        self.truing = truing
        self.builds = builds
        self.calibration = calibration
        self.mileage = mileage
        self.services = services
        self.settings = settings
    }

    public func seedIfEmpty() async throws {
        let existing = try await wheels.fetchAll()
        guard existing.isEmpty else { return }

        let cal = SpokeCalibration(
            toolName: "Park TM-1",
            gauge: "2.0",
            deflectionCSV: "15,20,25,30",
            kgfCSV: "60,80,100,120"
        )
        try await calibration.save(cal)

        try await components.save(SpokeComponent(kind: "rim", name: "Kinlin XR31", erdMm: 565))
        try await components.save(SpokeComponent(kind: "hub", name: "DT 350 Rear", flangeMm: 58, offsetMm: 34))
        try await components.save(SpokeComponent(kind: "spoke", name: "Sapim Race", gauge: "2.0"))

        let road = SpokeWheel(name: "Road Rear 32h", spokeCount: 32, cross: 3, erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 17, rightOffsetMm: 34)
        let gravel = SpokeWheel(name: "Gravel Front", spokeCount: 32, cross: 2, erdMm: 570, flangeDiameterMm: 52, leftOffsetMm: 32, rightOffsetMm: 32)
        let tour = SpokeWheel(name: "Touring Rear", spokeCount: 36, cross: 3, erdMm: 580, flangeDiameterMm: 62, leftOffsetMm: 18, rightOffsetMm: 36)
        for wheel in [road, gravel, tour] {
            try await wheels.save(wheel)
        }

        // 32 readings on road wheel; index 7 is soft (high deflection → low kgf warning)
        for i in 0..<32 {
            let side: SpokeSide = i % 2 == 0 ? .drive : .nonDrive
            let base = side == .drive ? 24.0 : 22.0
            let deflection = i == 7 ? 16.0 : base + Double(i % 3) * 0.3
            try await tensions.save(SpokeTensionReading(wheelId: road.id, spokeIndex: i, side: side, deflection: deflection))
        }
        for i in 0..<16 {
            try await tensions.save(SpokeTensionReading(wheelId: gravel.id, spokeIndex: i, side: .drive, deflection: 23 + Double(i % 2)))
        }
        for i in 0..<18 {
            try await tensions.save(SpokeTensionReading(wheelId: tour.id, spokeIndex: i, side: i % 2 == 0 ? .drive : .nonDrive, deflection: 25))
        }

        try await truing.save(SpokeTruingPass(
            wheelId: road.id,
            recordedAt: Date().addingTimeInterval(-86400 * 40),
            lateralCSV: "0.42,0.18,-0.05,0.24",
            radialCSV: "0.16,0.31,0.12,-0.04"
        ))
        // The road wheel sits 2.1 mm off centre, with runout riding on top of it.
        try await truing.save(SpokeTruingPass(
            wheelId: road.id,
            lateralCSV: Self.trace(count: 32, offset: 2.1, first: 0.34, second: 0.12, phase: 0.4),
            radialCSV: Self.trace(count: 32, offset: 0, first: 0.26, second: 0.09, phase: 1.1)
        ))
        try await truing.save(SpokeTruingPass(
            wheelId: gravel.id,
            lateralCSV: Self.trace(count: 32, offset: 0.3, first: 0.11, second: 0.05, phase: 2.2),
            radialCSV: Self.trace(count: 32, offset: 0, first: 0.14, second: 0.04, phase: 0.7)
        ))
        try await truing.save(SpokeTruingPass(
            wheelId: tour.id,
            lateralCSV: Self.trace(count: 36, offset: 1.2, first: 0.48, second: 0.2, phase: 1.7),
            radialCSV: Self.trace(count: 36, offset: 0, first: 0.37, second: 0.15, phase: 2.9)
        ))

        let start = Date().addingTimeInterval(-86400 * 10)
        try await builds.save(SpokeBuild(wheelId: road.id, startedAt: start, finishedAt: start.addingTimeInterval(3600 * 3.5), notes: "3x lace, stress relieved"))
        try await builds.save(SpokeBuild(wheelId: gravel.id, startedAt: start.addingTimeInterval(-86400), finishedAt: start.addingTimeInterval(-86400 + 7200), notes: "2x front"))

        try await mileage.save(SpokeMileageEntry(wheelId: road.id, date: Date().addingTimeInterval(-86400 * 20), km: 1200))
        try await mileage.save(SpokeMileageEntry(wheelId: road.id, date: Date(), km: 800))
        try await mileage.save(SpokeMileageEntry(wheelId: tour.id, km: 2400))

        try await services.save(SpokeServiceEvent(wheelId: road.id, title: "True and tension check", notes: "Spoke 7 soft"))
        try await services.save(SpokeServiceEvent(wheelId: tour.id, title: "Replace nipple", notes: "Drive side 12"))

        var prefs = try await settings.load()
        prefs.seedVersion = 1
        prefs.preferredGauge = "2.0"
        try await settings.save(prefs)
    }

    /// A runout trace with a first and second harmonic riding on an offset,
    /// which is what a real rim measures like on the stand.
    private static func trace(
        count: Int,
        offset: Double,
        first: Double,
        second: Double,
        phase: Double
    ) -> String {
        let samples = (0..<count).map { index -> Double in
            let turn = Double(index) / Double(count) * 2 * .pi
            return offset + first * sin(turn + phase) + second * sin(2 * turn + phase * 1.6)
        }
        return samples.map { String(format: "%.2f", $0) }.joined(separator: ",")
    }
}
