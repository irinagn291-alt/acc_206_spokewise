import Foundation

public protocol SpokeWheelRepository: Sendable {
    func fetchAll() async throws -> [SpokeWheel]
    func fetch(id: UUID) async throws -> SpokeWheel?
    func save(_ wheel: SpokeWheel) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeComponentRepository: Sendable {
    func fetchAll() async throws -> [SpokeComponent]
    func save(_ component: SpokeComponent) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeTensionRepository: Sendable {
    func fetch(wheelId: UUID) async throws -> [SpokeTensionReading]
    func save(_ reading: SpokeTensionReading) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeTruingRepository: Sendable {
    func fetch(wheelId: UUID) async throws -> [SpokeTruingPass]
    func save(_ pass: SpokeTruingPass) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeBuildRepository: Sendable {
    func fetch(wheelId: UUID) async throws -> [SpokeBuild]
    func fetchAll() async throws -> [SpokeBuild]
    func save(_ build: SpokeBuild) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeCalibrationRepository: Sendable {
    func fetchAll() async throws -> [SpokeCalibration]
    func save(_ calibration: SpokeCalibration) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeMileageRepository: Sendable {
    func fetch(wheelId: UUID) async throws -> [SpokeMileageEntry]
    func save(_ entry: SpokeMileageEntry) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeServiceRepository: Sendable {
    func fetchAll() async throws -> [SpokeServiceEvent]
    func fetch(wheelId: UUID) async throws -> [SpokeServiceEvent]
    func save(_ event: SpokeServiceEvent) async throws
    func delete(id: UUID) async throws
}

public protocol SpokeSettingsRepository: Sendable {
    func load() async throws -> SpokeSettings
    func save(_ settings: SpokeSettings) async throws
}
