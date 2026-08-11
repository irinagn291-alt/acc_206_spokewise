import Foundation

/// Reads one wheel as the polar artefact the hero draws.
public struct LoadRimArtefactUseCase: Sendable {
    private let wheels: SpokeWheelRepository
    private let tensions: SpokeTensionRepository
    private let truing: SpokeTruingRepository
    private let calibration: SpokeCalibrationRepository

    public init(
        wheels: SpokeWheelRepository,
        tensions: SpokeTensionRepository,
        truing: SpokeTruingRepository,
        calibration: SpokeCalibrationRepository
    ) {
        self.wheels = wheels
        self.tensions = tensions
        self.truing = truing
        self.calibration = calibration
    }

    public func callAsFunction(wheelId: UUID) async throws -> RimArtefact {
        guard let wheel = try await wheels.fetch(id: wheelId) else { throw SpokeStoreError.notFound }
        let table = try await calibration.fetchAll().first?.pairs ?? []
        let readings = try await tensions.fetch(wheelId: wheelId)
        let latest = try await truing.fetch(wheelId: wheelId).last
        let samples = RimArtefactBuilder.samples(
            spokeCount: wheel.spokeCount,
            readings: readings,
            calibration: table,
            lateralTrace: latest?.lateralSamples ?? [],
            radialTrace: latest?.radialSamples ?? []
        )
        return RimArtefact(
            wheel: wheel,
            samples: samples,
            readout: RimReadoutMath.readout(samples),
            calibration: table
        )
    }
}

/// Writes back one spoke dialled on the map. Tension lands on the spoke's own
/// reading; the two runout lenses land on the wheel's latest truing pass.
public struct DialSpokeUseCase: Sendable {
    private let tensions: SpokeTensionRepository
    private let truing: SpokeTruingRepository

    public init(tensions: SpokeTensionRepository, truing: SpokeTruingRepository) {
        self.tensions = tensions
        self.truing = truing
    }

    public func callAsFunction(
        wheelId: UUID,
        spokeCount: Int,
        index: Int,
        side: SpokeSide,
        lens: RimLens,
        value: Double
    ) async throws {
        let count = max(spokeCount, 1)
        guard index >= 0, index < count else { return }
        switch lens {
        case .tension:
            let existing = try await tensions.fetch(wheelId: wheelId).first { $0.spokeIndex == index }
            try await tensions.save(
                SpokeTensionReading(
                    id: existing?.id ?? UUID(),
                    wheelId: wheelId,
                    spokeIndex: index,
                    side: existing?.side ?? side,
                    deflection: value
                )
            )
        case .dish, .trueness:
            let latest = try await truing.fetch(wheelId: wheelId).last
            var lateral = RimPolarGeometry.resample(latest?.lateralSamples ?? [], to: count)
            var radial = RimPolarGeometry.resample(latest?.radialSamples ?? [], to: count)
            if lens == .dish { lateral[index] = value } else { radial[index] = value }
            try await truing.save(
                SpokeTruingPass(
                    id: latest?.id ?? UUID(),
                    wheelId: wheelId,
                    recordedAt: latest?.recordedAt ?? Date(),
                    lateralCSV: RimPolarGeometry.csv(lateral),
                    radialCSV: RimPolarGeometry.csv(radial)
                )
            )
        }
    }
}

/// Small-multiple source for the build ledger: every wheel as its own map.
public struct LoadRimThumbnailsUseCase: Sendable {
    private let wheels: SpokeWheelRepository
    private let artefact: LoadRimArtefactUseCase

    public init(wheels: SpokeWheelRepository, artefact: LoadRimArtefactUseCase) {
        self.wheels = wheels
        self.artefact = artefact
    }

    public func callAsFunction() async throws -> [RimArtefact] {
        var out: [RimArtefact] = []
        for wheel in try await wheels.fetchAll() {
            out.append(try await artefact(wheelId: wheel.id))
        }
        return out
    }
}
