import Foundation
import SQLite3

public final class SQLiteSpokeWheelRepository: SpokeWheelRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetchAll() async throws -> [SpokeWheel] {
        var rows: [SpokeWheel] = []
        try store.query("SELECT id,name,spoke_count,cross_count,erd_mm,flange_mm,left_offset,right_offset,hole_mm,created_at FROM wheels ORDER BY created_at") { stmt in
            rows.append(Self.map(stmt))
        }
        return rows
    }

    public func fetch(id: UUID) async throws -> SpokeWheel? {
        var row: SpokeWheel?
        try store.query("SELECT id,name,spoke_count,cross_count,erd_mm,flange_mm,left_offset,right_offset,hole_mm,created_at FROM wheels WHERE id=?") { stmt in
            SpokeSQL.bindText(stmt, 1, id.uuidString)
        } map: { stmt in
            row = Self.map(stmt)
        }
        return row
    }

    public func save(_ wheel: SpokeWheel) async throws {
        try store.run("""
        INSERT INTO wheels(id,name,spoke_count,cross_count,erd_mm,flange_mm,left_offset,right_offset,hole_mm,created_at)
        VALUES(?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          name=excluded.name, spoke_count=excluded.spoke_count, cross_count=excluded.cross_count,
          erd_mm=excluded.erd_mm, flange_mm=excluded.flange_mm, left_offset=excluded.left_offset,
          right_offset=excluded.right_offset, hole_mm=excluded.hole_mm
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, wheel.id.uuidString)
            SpokeSQL.bindText(stmt, 2, wheel.name)
            sqlite3_bind_int(stmt, 3, Int32(wheel.spokeCount))
            sqlite3_bind_int(stmt, 4, Int32(wheel.cross))
            sqlite3_bind_double(stmt, 5, wheel.erdMm)
            sqlite3_bind_double(stmt, 6, wheel.flangeDiameterMm)
            sqlite3_bind_double(stmt, 7, wheel.leftOffsetMm)
            sqlite3_bind_double(stmt, 8, wheel.rightOffsetMm)
            sqlite3_bind_double(stmt, 9, wheel.holeMm)
            sqlite3_bind_double(stmt, 10, wheel.createdAt.timeIntervalSince1970)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM wheels WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }

    private static func map(_ stmt: OpaquePointer) -> SpokeWheel {
        SpokeWheel(
            id: SpokeSQL.uuid(stmt, 0),
            name: SpokeSQL.text(stmt, 1),
            spokeCount: SpokeSQL.int(stmt, 2),
            cross: SpokeSQL.int(stmt, 3),
            erdMm: SpokeSQL.double(stmt, 4),
            flangeDiameterMm: SpokeSQL.double(stmt, 5),
            leftOffsetMm: SpokeSQL.double(stmt, 6),
            rightOffsetMm: SpokeSQL.double(stmt, 7),
            holeMm: SpokeSQL.double(stmt, 8),
            createdAt: SpokeSQL.date(stmt, 9)
        )
    }
}

public final class SQLiteSpokeComponentRepository: SpokeComponentRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetchAll() async throws -> [SpokeComponent] {
        var rows: [SpokeComponent] = []
        try store.query("SELECT id,kind,name,erd_mm,flange_mm,offset_mm,gauge,notes FROM components ORDER BY name") { stmt in
            rows.append(
                SpokeComponent(
                    id: SpokeSQL.uuid(stmt, 0),
                    kind: SpokeSQL.text(stmt, 1),
                    name: SpokeSQL.text(stmt, 2),
                    erdMm: SpokeSQL.optDouble(stmt, 3),
                    flangeMm: SpokeSQL.optDouble(stmt, 4),
                    offsetMm: SpokeSQL.optDouble(stmt, 5),
                    gauge: SpokeSQL.text(stmt, 6),
                    notes: SpokeSQL.text(stmt, 7)
                )
            )
        }
        return rows
    }

    public func save(_ component: SpokeComponent) async throws {
        try store.run("""
        INSERT INTO components(id,kind,name,erd_mm,flange_mm,offset_mm,gauge,notes)
        VALUES(?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          kind=excluded.kind, name=excluded.name, erd_mm=excluded.erd_mm, flange_mm=excluded.flange_mm,
          offset_mm=excluded.offset_mm, gauge=excluded.gauge, notes=excluded.notes
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, component.id.uuidString)
            SpokeSQL.bindText(stmt, 2, component.kind)
            SpokeSQL.bindText(stmt, 3, component.name)
            if let v = component.erdMm { sqlite3_bind_double(stmt, 4, v) } else { sqlite3_bind_null(stmt, 4) }
            if let v = component.flangeMm { sqlite3_bind_double(stmt, 5, v) } else { sqlite3_bind_null(stmt, 5) }
            if let v = component.offsetMm { sqlite3_bind_double(stmt, 6, v) } else { sqlite3_bind_null(stmt, 6) }
            SpokeSQL.bindText(stmt, 7, component.gauge)
            SpokeSQL.bindText(stmt, 8, component.notes)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM components WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }
}

public final class SQLiteSpokeTensionRepository: SpokeTensionRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetch(wheelId: UUID) async throws -> [SpokeTensionReading] {
        var rows: [SpokeTensionReading] = []
        try store.query("SELECT id,wheel_id,spoke_index,side,deflection,recorded_at FROM tensions WHERE wheel_id=? ORDER BY spoke_index") { stmt in
            SpokeSQL.bindText(stmt, 1, wheelId.uuidString)
        } map: { stmt in
            rows.append(
                SpokeTensionReading(
                    id: SpokeSQL.uuid(stmt, 0),
                    wheelId: SpokeSQL.uuid(stmt, 1),
                    spokeIndex: SpokeSQL.int(stmt, 2),
                    side: SpokeSide(rawValue: SpokeSQL.text(stmt, 3)) ?? .drive,
                    deflection: SpokeSQL.double(stmt, 4),
                    recordedAt: SpokeSQL.date(stmt, 5)
                )
            )
        }
        return rows
    }

    public func save(_ reading: SpokeTensionReading) async throws {
        try store.run("""
        INSERT INTO tensions(id,wheel_id,spoke_index,side,deflection,recorded_at)
        VALUES(?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          spoke_index=excluded.spoke_index, side=excluded.side, deflection=excluded.deflection
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, reading.id.uuidString)
            SpokeSQL.bindText(stmt, 2, reading.wheelId.uuidString)
            sqlite3_bind_int(stmt, 3, Int32(reading.spokeIndex))
            SpokeSQL.bindText(stmt, 4, reading.side.rawValue)
            sqlite3_bind_double(stmt, 5, reading.deflection)
            sqlite3_bind_double(stmt, 6, reading.recordedAt.timeIntervalSince1970)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM tensions WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }
}

public final class SQLiteSpokeTruingRepository: SpokeTruingRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetch(wheelId: UUID) async throws -> [SpokeTruingPass] {
        var rows: [SpokeTruingPass] = []
        try store.query("SELECT id,wheel_id,recorded_at,lateral_csv,radial_csv FROM truing WHERE wheel_id=? ORDER BY recorded_at") { stmt in
            SpokeSQL.bindText(stmt, 1, wheelId.uuidString)
        } map: { stmt in
            rows.append(
                SpokeTruingPass(
                    id: SpokeSQL.uuid(stmt, 0),
                    wheelId: SpokeSQL.uuid(stmt, 1),
                    recordedAt: SpokeSQL.date(stmt, 2),
                    lateralCSV: SpokeSQL.text(stmt, 3),
                    radialCSV: SpokeSQL.text(stmt, 4)
                )
            )
        }
        return rows
    }

    public func save(_ pass: SpokeTruingPass) async throws {
        try store.run("""
        INSERT INTO truing(id,wheel_id,recorded_at,lateral_csv,radial_csv)
        VALUES(?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET lateral_csv=excluded.lateral_csv, radial_csv=excluded.radial_csv
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, pass.id.uuidString)
            SpokeSQL.bindText(stmt, 2, pass.wheelId.uuidString)
            sqlite3_bind_double(stmt, 3, pass.recordedAt.timeIntervalSince1970)
            SpokeSQL.bindText(stmt, 4, pass.lateralCSV)
            SpokeSQL.bindText(stmt, 5, pass.radialCSV)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM truing WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }
}

public final class SQLiteSpokeBuildRepository: SpokeBuildRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetch(wheelId: UUID) async throws -> [SpokeBuild] {
        var rows: [SpokeBuild] = []
        try store.query("SELECT id,wheel_id,started_at,finished_at,notes FROM builds WHERE wheel_id=? ORDER BY started_at DESC") { stmt in
            SpokeSQL.bindText(stmt, 1, wheelId.uuidString)
        } map: { stmt in
            rows.append(Self.map(stmt))
        }
        return rows
    }

    public func fetchAll() async throws -> [SpokeBuild] {
        var rows: [SpokeBuild] = []
        try store.query("SELECT id,wheel_id,started_at,finished_at,notes FROM builds ORDER BY started_at DESC") { stmt in
            rows.append(Self.map(stmt))
        }
        return rows
    }

    public func save(_ build: SpokeBuild) async throws {
        try store.run("""
        INSERT INTO builds(id,wheel_id,started_at,finished_at,notes)
        VALUES(?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET finished_at=excluded.finished_at, notes=excluded.notes
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, build.id.uuidString)
            SpokeSQL.bindText(stmt, 2, build.wheelId.uuidString)
            sqlite3_bind_double(stmt, 3, build.startedAt.timeIntervalSince1970)
            if let end = build.finishedAt { sqlite3_bind_double(stmt, 4, end.timeIntervalSince1970) } else { sqlite3_bind_null(stmt, 4) }
            SpokeSQL.bindText(stmt, 5, build.notes)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM builds WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }

    private static func map(_ stmt: OpaquePointer) -> SpokeBuild {
        SpokeBuild(
            id: SpokeSQL.uuid(stmt, 0),
            wheelId: SpokeSQL.uuid(stmt, 1),
            startedAt: SpokeSQL.date(stmt, 2),
            finishedAt: SpokeSQL.optDate(stmt, 3),
            notes: SpokeSQL.text(stmt, 4)
        )
    }
}

public final class SQLiteSpokeCalibrationRepository: SpokeCalibrationRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetchAll() async throws -> [SpokeCalibration] {
        var rows: [SpokeCalibration] = []
        try store.query("SELECT id,tool_name,gauge,deflection_csv,kgf_csv FROM calibrations") { stmt in
            rows.append(
                SpokeCalibration(
                    id: SpokeSQL.uuid(stmt, 0),
                    toolName: SpokeSQL.text(stmt, 1),
                    gauge: SpokeSQL.text(stmt, 2),
                    deflectionCSV: SpokeSQL.text(stmt, 3),
                    kgfCSV: SpokeSQL.text(stmt, 4)
                )
            )
        }
        return rows
    }

    public func save(_ calibration: SpokeCalibration) async throws {
        try store.run("""
        INSERT INTO calibrations(id,tool_name,gauge,deflection_csv,kgf_csv)
        VALUES(?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          tool_name=excluded.tool_name, gauge=excluded.gauge,
          deflection_csv=excluded.deflection_csv, kgf_csv=excluded.kgf_csv
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, calibration.id.uuidString)
            SpokeSQL.bindText(stmt, 2, calibration.toolName)
            SpokeSQL.bindText(stmt, 3, calibration.gauge)
            SpokeSQL.bindText(stmt, 4, calibration.deflectionCSV)
            SpokeSQL.bindText(stmt, 5, calibration.kgfCSV)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM calibrations WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }
}

public final class SQLiteSpokeMileageRepository: SpokeMileageRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetch(wheelId: UUID) async throws -> [SpokeMileageEntry] {
        var rows: [SpokeMileageEntry] = []
        try store.query("SELECT id,wheel_id,date,km FROM mileage WHERE wheel_id=? ORDER BY date") { stmt in
            SpokeSQL.bindText(stmt, 1, wheelId.uuidString)
        } map: { stmt in
            rows.append(
                SpokeMileageEntry(
                    id: SpokeSQL.uuid(stmt, 0),
                    wheelId: SpokeSQL.uuid(stmt, 1),
                    date: SpokeSQL.date(stmt, 2),
                    km: SpokeSQL.double(stmt, 3)
                )
            )
        }
        return rows
    }

    public func save(_ entry: SpokeMileageEntry) async throws {
        try store.run("""
        INSERT INTO mileage(id,wheel_id,date,km) VALUES(?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET date=excluded.date, km=excluded.km
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, entry.id.uuidString)
            SpokeSQL.bindText(stmt, 2, entry.wheelId.uuidString)
            sqlite3_bind_double(stmt, 3, entry.date.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 4, entry.km)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM mileage WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }
}

public final class SQLiteSpokeServiceRepository: SpokeServiceRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func fetchAll() async throws -> [SpokeServiceEvent] {
        var rows: [SpokeServiceEvent] = []
        try store.query("SELECT id,wheel_id,date,title,notes FROM services ORDER BY date DESC") { stmt in
            rows.append(Self.map(stmt))
        }
        return rows
    }

    public func fetch(wheelId: UUID) async throws -> [SpokeServiceEvent] {
        var rows: [SpokeServiceEvent] = []
        try store.query("SELECT id,wheel_id,date,title,notes FROM services WHERE wheel_id=? ORDER BY date DESC") { stmt in
            SpokeSQL.bindText(stmt, 1, wheelId.uuidString)
        } map: { stmt in
            rows.append(Self.map(stmt))
        }
        return rows
    }

    public func save(_ event: SpokeServiceEvent) async throws {
        try store.run("""
        INSERT INTO services(id,wheel_id,date,title,notes) VALUES(?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET title=excluded.title, notes=excluded.notes, date=excluded.date
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, event.id.uuidString)
            SpokeSQL.bindText(stmt, 2, event.wheelId.uuidString)
            sqlite3_bind_double(stmt, 3, event.date.timeIntervalSince1970)
            SpokeSQL.bindText(stmt, 4, event.title)
            SpokeSQL.bindText(stmt, 5, event.notes)
        }
    }

    public func delete(id: UUID) async throws {
        try store.run("DELETE FROM services WHERE id=?") { SpokeSQL.bindText($0, 1, id.uuidString) }
    }

    private static func map(_ stmt: OpaquePointer) -> SpokeServiceEvent {
        SpokeServiceEvent(
            id: SpokeSQL.uuid(stmt, 0),
            wheelId: SpokeSQL.uuid(stmt, 1),
            date: SpokeSQL.date(stmt, 2),
            title: SpokeSQL.text(stmt, 3),
            notes: SpokeSQL.text(stmt, 4)
        )
    }
}

public final class SQLiteSpokeSettingsRepository: SpokeSettingsRepository, @unchecked Sendable {
    private let store: SpokeSQLiteStore
    public init(store: SpokeSQLiteStore) { self.store = store }

    public func load() async throws -> SpokeSettings {
        var settings = SpokeSettings()
        var found = false
        try store.query("SELECT preferred_gauge,tension_unit,seed_version FROM settings WHERE id=1") { stmt in
            settings = SpokeSettings(
                preferredGauge: SpokeSQL.text(stmt, 0),
                tensionUnit: SpokeSQL.text(stmt, 1),
                seedVersion: SpokeSQL.int(stmt, 2)
            )
            found = true
        }
        if !found {
            try await save(settings)
        }
        return settings
    }

    public func save(_ settings: SpokeSettings) async throws {
        try store.run("""
        INSERT INTO settings(id,preferred_gauge,tension_unit,seed_version)
        VALUES(1,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          preferred_gauge=excluded.preferred_gauge,
          tension_unit=excluded.tension_unit,
          seed_version=excluded.seed_version
        """) { stmt in
            SpokeSQL.bindText(stmt, 1, settings.preferredGauge)
            SpokeSQL.bindText(stmt, 2, settings.tensionUnit)
            sqlite3_bind_int(stmt, 3, Int32(settings.seedVersion))
        }
    }
}
