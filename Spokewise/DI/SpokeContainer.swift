import Foundation

/// Factory for Spokewise dependencies.
@MainActor
public final class SpokeContainer {
    public let store: SpokeSQLiteStore
    public let wheelRepository: SpokeWheelRepository
    public let componentRepository: SpokeComponentRepository
    public let tensionRepository: SpokeTensionRepository
    public let truingRepository: SpokeTruingRepository
    public let buildRepository: SpokeBuildRepository
    public let calibrationRepository: SpokeCalibrationRepository
    public let mileageRepository: SpokeMileageRepository
    public let serviceRepository: SpokeServiceRepository
    public let settingsRepository: SpokeSettingsRepository

    public init(store: SpokeSQLiteStore) {
        self.store = store
        wheelRepository = SQLiteSpokeWheelRepository(store: store)
        componentRepository = SQLiteSpokeComponentRepository(store: store)
        tensionRepository = SQLiteSpokeTensionRepository(store: store)
        truingRepository = SQLiteSpokeTruingRepository(store: store)
        buildRepository = SQLiteSpokeBuildRepository(store: store)
        calibrationRepository = SQLiteSpokeCalibrationRepository(store: store)
        mileageRepository = SQLiteSpokeMileageRepository(store: store)
        serviceRepository = SQLiteSpokeServiceRepository(store: store)
        settingsRepository = SQLiteSpokeSettingsRepository(store: store)
    }

    public static func live() throws -> SpokeContainer { SpokeContainer(store: try SpokeSQLiteStore.onDisk()) }
    public static func preview() -> SpokeContainer { SpokeContainer(store: try! SpokeSQLiteStore.inMemory()) }

    public var loadWheels: LoadWheelsUseCase { LoadWheelsUseCase(wheels: wheelRepository) }
    public var loadBundle: LoadWheelBundleUseCase {
        LoadWheelBundleUseCase(wheels: wheelRepository, tensions: tensionRepository, truing: truingRepository, builds: buildRepository, mileage: mileageRepository, services: serviceRepository)
    }
    public var loadStats: LoadSpokeStatsUseCase {
        LoadSpokeStatsUseCase(wheels: wheelRepository, tensions: tensionRepository, truing: truingRepository, builds: buildRepository, mileage: mileageRepository, calibration: calibrationRepository)
    }
    public var loadArtefact: LoadRimArtefactUseCase {
        LoadRimArtefactUseCase(wheels: wheelRepository, tensions: tensionRepository, truing: truingRepository, calibration: calibrationRepository)
    }
    public var dialSpoke: DialSpokeUseCase { DialSpokeUseCase(tensions: tensionRepository, truing: truingRepository) }
    public var loadThumbnails: LoadRimThumbnailsUseCase {
        LoadRimThumbnailsUseCase(wheels: wheelRepository, artefact: loadArtefact)
    }
    public var exportCSV: ExportTensionCSVUseCase { ExportTensionCSVUseCase(loadBundle: loadBundle, calibration: calibrationRepository) }
    public var seeder: SpokeDemoSeeder {
        SpokeDemoSeeder(wheels: wheelRepository, components: componentRepository, tensions: tensionRepository, truing: truingRepository, builds: buildRepository, calibration: calibrationRepository, mileage: mileageRepository, services: serviceRepository, settings: settingsRepository)
    }
}
