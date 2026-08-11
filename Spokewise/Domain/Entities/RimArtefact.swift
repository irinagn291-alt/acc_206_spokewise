import Foundation

/// One wheel read as a polar map: the artefact all three lenses look at.
public struct RimArtefact: Sendable {
    public let wheel: SpokeWheel
    public let samples: [RimSample]
    public let readout: RimReadout
    public let calibration: [(Double, Double)]

    public init(
        wheel: SpokeWheel,
        samples: [RimSample],
        readout: RimReadout,
        calibration: [(Double, Double)] = []
    ) {
        self.wheel = wheel
        self.samples = samples
        self.readout = readout
        self.calibration = calibration
    }

    public var title: String {
        RimReadoutMath.rimTitle(name: wheel.name, spokeCount: wheel.spokeCount)
    }

    public func sample(at index: Int) -> RimSample? {
        samples.first { $0.index == index }
    }
}

/// Folds stored readings, calibration and runout traces into one sample per
/// spoke hole, filling unread holes with the working mean so the map is whole.
public enum RimArtefactBuilder: Sendable {
    public static func samples(
        spokeCount: Int,
        readings: [SpokeTensionReading],
        calibration: [(Double, Double)],
        lateralTrace: [Double],
        radialTrace: [Double]
    ) -> [RimSample] {
        let count = max(spokeCount, 1)
        let lateral = RimPolarGeometry.resample(lateralTrace, to: count)
        let radial = RimPolarGeometry.resample(radialTrace, to: count)

        var byHole: [Int: SpokeTensionReading] = [:]
        for reading in readings where reading.spokeIndex >= 0 && reading.spokeIndex < count {
            byHole[reading.spokeIndex] = reading
        }
        let measured = byHole.values.map { SpokeMath.kgf(deflection: $0.deflection, table: calibration) }
        let working = measured.isEmpty ? 0 : measured.reduce(0, +) / Double(measured.count)

        return (0..<count).map { hole in
            let reading = byHole[hole]
            return RimSample(
                index: hole,
                side: reading?.side ?? RimPolarGeometry.lacedSide(index: hole),
                tensionKgf: reading.map { SpokeMath.kgf(deflection: $0.deflection, table: calibration) } ?? working,
                deflection: reading?.deflection ?? 0,
                lateralMm: lateral[hole],
                radialMm: radial[hole],
                isMeasured: reading != nil
            )
        }
    }
}
