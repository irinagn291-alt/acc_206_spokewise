import Foundation

public struct LoadWheelsUseCase: Sendable {
    private let wheels: SpokeWheelRepository
    public init(wheels: SpokeWheelRepository) { self.wheels = wheels }
    public func callAsFunction() async throws -> [SpokeWheel] {
        try await wheels.fetchAll()
    }
}

public struct LoadWheelBundleUseCase: Sendable {
    private let wheels: SpokeWheelRepository
    private let tensions: SpokeTensionRepository
    private let truing: SpokeTruingRepository
    private let builds: SpokeBuildRepository
    private let mileage: SpokeMileageRepository
    private let services: SpokeServiceRepository

    public init(
        wheels: SpokeWheelRepository,
        tensions: SpokeTensionRepository,
        truing: SpokeTruingRepository,
        builds: SpokeBuildRepository,
        mileage: SpokeMileageRepository,
        services: SpokeServiceRepository
    ) {
        self.wheels = wheels
        self.tensions = tensions
        self.truing = truing
        self.builds = builds
        self.mileage = mileage
        self.services = services
    }

    public func callAsFunction(wheelId: UUID) async throws -> SpokeWheelBundle {
        guard let wheel = try await wheels.fetch(id: wheelId) else { throw SpokeStoreError.notFound }
        return SpokeWheelBundle(
            wheel: wheel,
            tensions: try await tensions.fetch(wheelId: wheelId),
            truing: try await truing.fetch(wheelId: wheelId),
            builds: try await builds.fetch(wheelId: wheelId),
            mileage: try await mileage.fetch(wheelId: wheelId),
            services: try await services.fetch(wheelId: wheelId)
        )
    }
}

public struct LoadSpokeStatsUseCase: Sendable {
    private let wheels: SpokeWheelRepository
    private let tensions: SpokeTensionRepository
    private let truing: SpokeTruingRepository
    private let builds: SpokeBuildRepository
    private let mileage: SpokeMileageRepository
    private let calibration: SpokeCalibrationRepository

    public init(
        wheels: SpokeWheelRepository,
        tensions: SpokeTensionRepository,
        truing: SpokeTruingRepository,
        builds: SpokeBuildRepository,
        mileage: SpokeMileageRepository,
        calibration: SpokeCalibrationRepository
    ) {
        self.wheels = wheels
        self.tensions = tensions
        self.truing = truing
        self.builds = builds
        self.mileage = mileage
        self.calibration = calibration
    }

    public func callAsFunction() async throws -> SpokeStatsSnapshot {
        let table = try await calibration.fetchAll().first?.pairs ?? []
        let allWheels = try await wheels.fetchAll()
        var sdHistory: [Double] = []
        var byPosition = Array(repeating: 0.0, count: 32)
        var positionCounts = Array(repeating: 0, count: 32)
        var buildHours: [Double] = []
        var dishValues: [Double] = []
        var kmGaps: [Double] = []
        var radial: [Double] = []
        var allKgf: [Double] = []

        for wheel in allWheels {
            let readings = try await tensions.fetch(wheelId: wheel.id)
            let kgfs = readings.map { SpokeMath.kgf(deflection: $0.deflection, table: table) }
            allKgf.append(contentsOf: kgfs)
            let drive = readings.filter { $0.side == .drive }.map { SpokeMath.kgf(deflection: $0.deflection, table: table) }
            let nonDrive = readings.filter { $0.side == .nonDrive }.map { SpokeMath.kgf(deflection: $0.deflection, table: table) }
            let bal = SpokeMath.tensionBalance(drive: drive, nonDrive: nonDrive)
            if !readings.isEmpty { sdHistory.append(bal.sd) }
            for reading in readings {
                let idx = max(0, min(31, reading.spokeIndex % 32))
                byPosition[idx] += SpokeMath.kgf(deflection: reading.deflection, table: table)
                positionCounts[idx] += 1
            }
            dishValues.append(abs(SpokeMath.dishErrorMm(leftOffset: wheel.leftOffsetMm, rightOffset: wheel.rightOffsetMm)))
            let passes = try await truing.fetch(wheelId: wheel.id)
            if let last = passes.last { radial = last.radialSamples }
            let buildsForWheel = try await builds.fetch(wheelId: wheel.id)
            for build in buildsForWheel {
                if let end = build.finishedAt {
                    buildHours.append(end.timeIntervalSince(build.startedAt) / 3600)
                }
            }
            let miles = try await mileage.fetch(wheelId: wheel.id).map(\.km)
            if passes.count >= 2, miles.count >= 1 {
                kmGaps.append(miles.reduce(0, +) / Double(passes.count))
            } else if !miles.isEmpty {
                kmGaps.append(miles.reduce(0, +))
            }
        }

        for i in 0..<32 {
            if positionCounts[i] > 0 { byPosition[i] /= Double(positionCounts[i]) }
        }
        if sdHistory.isEmpty { sdHistory = [0] }
        if byPosition.allSatisfy({ $0 == 0 }) {
            byPosition = Array(repeating: 100, count: 32)
        }

        let histBins = Self.histogram(allKgf, bins: 8)
        return SpokeStatsSnapshot(
            tensionSDHistory: sdHistory,
            tensionByPosition: byPosition,
            meanBuildHours: buildHours.isEmpty ? 0 : buildHours.reduce(0, +) / Double(buildHours.count),
            dishDriftMm: dishValues.isEmpty ? 0 : dishValues.reduce(0, +) / Double(dishValues.count),
            kmBetweenTruings: kmGaps.isEmpty ? 0 : kmGaps.reduce(0, +) / Double(kmGaps.count),
            radialSamples: radial.isEmpty ? (0..<16).map { _ in 0 } : radial,
            tensionHistogram: histBins
        )
    }

    private static func histogram(_ values: [Double], bins: Int) -> [Double] {
        guard !values.isEmpty, bins > 0 else { return Array(repeating: 0, count: bins) }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let span = max(0.0001, maxV - minV)
        var counts = Array(repeating: 0.0, count: bins)
        for v in values {
            let idx = min(bins - 1, Int(((v - minV) / span) * Double(bins)))
            counts[idx] += 1
        }
        return counts
    }
}

public struct ExportTensionCSVUseCase: Sendable {
    private let loadBundle: LoadWheelBundleUseCase
    private let calibration: SpokeCalibrationRepository

    public init(loadBundle: LoadWheelBundleUseCase, calibration: SpokeCalibrationRepository) {
        self.loadBundle = loadBundle
        self.calibration = calibration
    }

    public func callAsFunction(wheelId: UUID) async throws -> String {
        let bundle = try await loadBundle(wheelId: wheelId)
        let table = try await calibration.fetchAll().first?.pairs ?? []
        var lines = ["spoke_index,side,deflection,kgf"]
        let sorted = bundle.tensions.sorted { $0.spokeIndex < $1.spokeIndex }
        for reading in sorted {
            let kgf = SpokeMath.kgf(deflection: reading.deflection, table: table)
            lines.append("\(reading.spokeIndex),\(reading.side.rawValue),\(reading.deflection),\(kgf)")
        }
        return lines.joined(separator: "\n")
    }
}
