import Foundation

/// Workshop wheel geometry used for length and dish calculations.
public struct SpokeWheel: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var spokeCount: Int
    public var cross: Int
    public var erdMm: Double
    public var flangeDiameterMm: Double
    public var leftOffsetMm: Double
    public var rightOffsetMm: Double
    public var holeMm: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        spokeCount: Int = 32,
        cross: Int = 3,
        erdMm: Double,
        flangeDiameterMm: Double,
        leftOffsetMm: Double,
        rightOffsetMm: Double,
        holeMm: Double = 2.6,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.spokeCount = spokeCount
        self.cross = cross
        self.erdMm = erdMm
        self.flangeDiameterMm = flangeDiameterMm
        self.leftOffsetMm = leftOffsetMm
        self.rightOffsetMm = rightOffsetMm
        self.holeMm = holeMm
        self.createdAt = createdAt
    }
}

public enum SpokeSide: String, Sendable, CaseIterable, Hashable {
    case drive
    case nonDrive
}

/// Single tensiometer deflection at a spoke index.
public struct SpokeTensionReading: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var wheelId: UUID
    public var spokeIndex: Int
    public var side: SpokeSide
    public var deflection: Double
    public var recordedAt: Date

    public init(
        id: UUID = UUID(),
        wheelId: UUID,
        spokeIndex: Int,
        side: SpokeSide,
        deflection: Double,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.wheelId = wheelId
        self.spokeIndex = spokeIndex
        self.side = side
        self.deflection = deflection
        self.recordedAt = recordedAt
    }
}

/// Lateral and radial runout samples stored as CSV around the rim.
public struct SpokeTruingPass: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var wheelId: UUID
    public var recordedAt: Date
    public var lateralCSV: String
    public var radialCSV: String

    public init(
        id: UUID = UUID(),
        wheelId: UUID,
        recordedAt: Date = Date(),
        lateralCSV: String,
        radialCSV: String
    ) {
        self.id = id
        self.wheelId = wheelId
        self.recordedAt = recordedAt
        self.lateralCSV = lateralCSV
        self.radialCSV = radialCSV
    }

    public var lateralSamples: [Double] {
        lateralCSV.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    public var radialSamples: [Double] {
        radialCSV.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }
}

public struct SpokeBuild: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var wheelId: UUID
    public var startedAt: Date
    public var finishedAt: Date?
    public var notes: String

    public init(
        id: UUID = UUID(),
        wheelId: UUID,
        startedAt: Date,
        finishedAt: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.wheelId = wheelId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.notes = notes
    }
}

public struct SpokeComponent: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var kind: String
    public var name: String
    public var erdMm: Double?
    public var flangeMm: Double?
    public var offsetMm: Double?
    public var gauge: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        kind: String,
        name: String,
        erdMm: Double? = nil,
        flangeMm: Double? = nil,
        offsetMm: Double? = nil,
        gauge: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.erdMm = erdMm
        self.flangeMm = flangeMm
        self.offsetMm = offsetMm
        self.gauge = gauge
        self.notes = notes
    }
}

/// Tensiometer conversion table for one tool and gauge.
public struct SpokeCalibration: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var toolName: String
    public var gauge: String
    public var deflectionCSV: String
    public var kgfCSV: String

    public init(
        id: UUID = UUID(),
        toolName: String,
        gauge: String,
        deflectionCSV: String,
        kgfCSV: String
    ) {
        self.id = id
        self.toolName = toolName
        self.gauge = gauge
        self.deflectionCSV = deflectionCSV
        self.kgfCSV = kgfCSV
    }

    public var pairs: [(Double, Double)] {
        let defs = deflectionCSV.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        let kgfs = kgfCSV.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return zip(defs, kgfs).map { ($0, $1) }
    }
}

public struct SpokeMileageEntry: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var wheelId: UUID
    public var date: Date
    public var km: Double

    public init(id: UUID = UUID(), wheelId: UUID, date: Date = Date(), km: Double) {
        self.id = id
        self.wheelId = wheelId
        self.date = date
        self.km = km
    }
}

public struct SpokeServiceEvent: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var wheelId: UUID
    public var date: Date
    public var title: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        wheelId: UUID,
        date: Date = Date(),
        title: String,
        notes: String = ""
    ) {
        self.id = id
        self.wheelId = wheelId
        self.date = date
        self.title = title
        self.notes = notes
    }
}

/// App preferences persisted in the SQLite settings row.
public struct SpokeSettings: Sendable, Hashable {
    public var preferredGauge: String
    public var tensionUnit: String
    public var seedVersion: Int

    public init(preferredGauge: String = "2.0", tensionUnit: String = "kgf", seedVersion: Int = 0) {
        self.preferredGauge = preferredGauge
        self.tensionUnit = tensionUnit
        self.seedVersion = seedVersion
    }
}

public struct SpokeLengthResult: Sendable, Hashable {
    public let leftMm: Double
    public let rightMm: Double
    public init(leftMm: Double, rightMm: Double) {
        self.leftMm = leftMm
        self.rightMm = rightMm
    }
}

public struct SpokeTensionBalance: Sendable, Hashable {
    public let mean: Double
    public let sd: Double
    public let spreadPercent: Double
    public let driveToNonDrive: Double
    public init(mean: Double, sd: Double, spreadPercent: Double, driveToNonDrive: Double) {
        self.mean = mean
        self.sd = sd
        self.spreadPercent = spreadPercent
        self.driveToNonDrive = driveToNonDrive
    }
}

public struct SpokeWheelBundle: Sendable {
    public var wheel: SpokeWheel
    public var tensions: [SpokeTensionReading]
    public var truing: [SpokeTruingPass]
    public var builds: [SpokeBuild]
    public var mileage: [SpokeMileageEntry]
    public var services: [SpokeServiceEvent]
}

public struct SpokeStatsSnapshot: Sendable {
    public var tensionSDHistory: [Double]
    public var tensionByPosition: [Double]
    public var meanBuildHours: Double
    public var dishDriftMm: Double
    public var kmBetweenTruings: Double
    public var radialSamples: [Double]
    public var tensionHistogram: [Double]
}

public struct LacingPattern: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let cross: Int
    public let lengthEffect: String
    public let useCase: String
}

public enum SpokeStoreError: Error, LocalizedError, Sendable {
    case storeFailure(String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .storeFailure(let message): return message
        case .notFound: return "Record not found"
        }
    }
}
