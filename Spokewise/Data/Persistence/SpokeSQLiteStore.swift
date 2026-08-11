import Foundation
import SQLite3

/// Thin libsqlite3 wrapper for Spokewise.
public final class SpokeSQLiteStore: @unchecked Sendable {
    nonisolated(unsafe) private var handle: OpaquePointer?

    public init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK, let db else {
            throw SpokeStoreError.storeFailure("Unable to open SQLite store")
        }
        handle = db
        try exec("PRAGMA foreign_keys = ON;")
        try exec("PRAGMA busy_timeout = 5000;")
        try migrate()
    }

    public static func onDisk() throws -> SpokeSQLiteStore {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = root.appendingPathComponent("Spokewise", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try SpokeSQLiteStore(path: dir.appendingPathComponent("spokewise.sqlite").path)
    }

    public static func inMemory() throws -> SpokeSQLiteStore {
        try SpokeSQLiteStore(path: ":memory:")
    }

    deinit { if let handle { sqlite3_close_v2(handle) } }

    public func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(handle, sql, nil, nil, &err)
        defer { sqlite3_free(err) }
        guard code == SQLITE_OK else {
            throw SpokeStoreError.storeFailure(err.map { String(cString: $0) } ?? "exec failed")
        }
    }

    public func run(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) throws {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SpokeStoreError.storeFailure(String(cString: sqlite3_errmsg(handle)))
        }
    }

    public func query(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil, map: (OpaquePointer) -> Void) throws {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW { map(stmt) }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw SpokeStoreError.storeFailure(String(cString: sqlite3_errmsg(handle)))
        }
        return stmt
    }

    private func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS wheels(
          id TEXT PRIMARY KEY, name TEXT NOT NULL, spoke_count INTEGER, cross_count INTEGER,
          erd_mm REAL, flange_mm REAL, left_offset REAL, right_offset REAL, hole_mm REAL, created_at REAL
        );
        CREATE TABLE IF NOT EXISTS components(
          id TEXT PRIMARY KEY, kind TEXT, name TEXT, erd_mm REAL, flange_mm REAL, offset_mm REAL, gauge TEXT, notes TEXT
        );
        CREATE TABLE IF NOT EXISTS tensions(
          id TEXT PRIMARY KEY, wheel_id TEXT, spoke_index INTEGER, side TEXT, deflection REAL, recorded_at REAL
        );
        CREATE TABLE IF NOT EXISTS truing(
          id TEXT PRIMARY KEY, wheel_id TEXT, recorded_at REAL, lateral_csv TEXT, radial_csv TEXT
        );
        CREATE TABLE IF NOT EXISTS builds(
          id TEXT PRIMARY KEY, wheel_id TEXT, started_at REAL, finished_at REAL, notes TEXT
        );
        CREATE TABLE IF NOT EXISTS calibrations(
          id TEXT PRIMARY KEY, tool_name TEXT, gauge TEXT, deflection_csv TEXT, kgf_csv TEXT
        );
        CREATE TABLE IF NOT EXISTS mileage(
          id TEXT PRIMARY KEY, wheel_id TEXT, date REAL, km REAL
        );
        CREATE TABLE IF NOT EXISTS services(
          id TEXT PRIMARY KEY, wheel_id TEXT, date REAL, title TEXT, notes TEXT
        );
        CREATE TABLE IF NOT EXISTS settings(
          id INTEGER PRIMARY KEY, preferred_gauge TEXT, tension_unit TEXT, seed_version INTEGER
        );
        """)
    }
}

enum SpokeSQL {
    static func text(_ stmt: OpaquePointer, _ i: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, i) else { return "" }
        return String(cString: c)
    }
    static func uuid(_ stmt: OpaquePointer, _ i: Int32) -> UUID { UUID(uuidString: text(stmt, i)) ?? UUID() }
    static func double(_ stmt: OpaquePointer, _ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
    static func int(_ stmt: OpaquePointer, _ i: Int32) -> Int { Int(sqlite3_column_int(stmt, i)) }
    static func date(_ stmt: OpaquePointer, _ i: Int32) -> Date { Date(timeIntervalSince1970: double(stmt, i)) }
    static func optDate(_ stmt: OpaquePointer, _ i: Int32) -> Date? {
        sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : date(stmt, i)
    }
    static func optDouble(_ stmt: OpaquePointer, _ i: Int32) -> Double? {
        sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : double(stmt, i)
    }
    static func bindText(_ stmt: OpaquePointer, _ i: Int32, _ v: String) {
        sqlite3_bind_text(stmt, i, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
}
