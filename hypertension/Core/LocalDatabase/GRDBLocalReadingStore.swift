import Foundation
import GRDB

struct LocalQueuedReading: Identifiable, Hashable {
    let id: Int64
    let userId: String
    let clientId: UUID
    let systolic: Int
    let diastolic: Int
    let pulse: Int?
    let measuredAt: Date
    let source: String
    let note: String?
    let syncStatus: String
    let serverId: String?
}

@MainActor
final class GRDBLocalReadingStore {
    static let shared = GRDBLocalReadingStore()

    private let dbQueue: DatabaseQueue
    private let isoFormatter = ISO8601DateFormatter()

    private init() {
        do {
            let folderURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let databaseURL = folderURL.appendingPathComponent("bphealth.sqlite")
            dbQueue = try DatabaseQueue(path: databaseURL.path)
            try migrator.migrate(dbQueue)
        } catch {
            fatalError("Unable to open local database: \(error)")
        }
    }

    func enqueue(_ draft: BPReadingDraft, userId: String, clientId: UUID = UUID()) throws {
        guard !userId.isEmpty else {
            return
        }

        guard let systolic = Int(draft.systolic.trimmingCharacters(in: .whitespacesAndNewlines)),
              let diastolic = Int(draft.diastolic.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        let pulseText = draft.pulse.trimmingCharacters(in: .whitespacesAndNewlines)
        let pulse = pulseText.isEmpty ? nil : Int(pulseText)
        let source = draft.source == .manual ? "manual" : "camera_ocr"

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO local_blood_pressure_readings
                (user_id, client_id, systolic, diastolic, pulse, measured_at, source, note, sync_status, created_at, updated_at)
                VALUES (:userId, :clientId, :systolic, :diastolic, :pulse, :measuredAt, :source, :note, :syncStatus, :createdAt, :updatedAt)
                """,
                arguments: [
                    "userId": userId,
                    "clientId": clientId.uuidString,
                    "systolic": systolic,
                    "diastolic": diastolic,
                    "pulse": pulse,
                    "measuredAt": isoFormatter.string(from: draft.measuredAt),
                    "source": source,
                    "note": nil,
                    "syncStatus": "localOnly",
                    "createdAt": isoFormatter.string(from: Date()),
                    "updatedAt": isoFormatter.string(from: Date())
                ]
            )
        }
    }

    func pendingReadings(userId: String) throws -> [LocalQueuedReading] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, user_id, client_id, systolic, diastolic, pulse, measured_at, source, note, sync_status, server_id
                FROM local_blood_pressure_readings
                WHERE user_id = :userId AND sync_status IN ('localOnly', 'syncFailed')
                ORDER BY measured_at ASC
                """,
                arguments: ["userId": userId]
            )

            return rows.compactMap(mapRow)
        }
    }

    func markSyncing(clientIds: [UUID]) throws {
        try updateStatus("syncing", clientIds: clientIds)
    }

    func markSyncFailed(clientIds: [UUID]) throws {
        try updateStatus("syncFailed", clientIds: clientIds)
    }

    func markSynced(clientId: UUID, serverId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE local_blood_pressure_readings
                SET sync_status = :syncStatus, server_id = :serverId, updated_at = :updatedAt
                WHERE client_id = :clientId
                """,
                arguments: [
                    "syncStatus": "synced",
                    "serverId": serverId,
                    "updatedAt": isoFormatter.string(from: Date()),
                    "clientId": clientId.uuidString
                ]
            )
        }
    }

    func clearAll() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM local_blood_pressure_readings")
        }
    }

    private func updateStatus(_ status: String, clientIds: [UUID]) throws {
        guard !clientIds.isEmpty else {
            return
        }

        try dbQueue.write { db in
            for clientId in clientIds {
                try db.execute(
                    sql: """
                    UPDATE local_blood_pressure_readings
                    SET sync_status = :syncStatus, updated_at = :updatedAt
                    WHERE client_id = :clientId
                    """,
                    arguments: [
                        "syncStatus": status,
                        "updatedAt": isoFormatter.string(from: Date()),
                        "clientId": clientId.uuidString
                    ]
                )
            }
        }
    }

    private func mapRow(_ row: Row) -> LocalQueuedReading? {
        let clientIdString: String = row["client_id"]
        let measuredAtString: String = row["measured_at"]

        guard
            let clientId = UUID(uuidString: clientIdString),
            let measuredAt = isoFormatter.date(from: measuredAtString)
        else {
            return nil
        }

        return LocalQueuedReading(
            id: row["id"],
            userId: row["user_id"],
            clientId: clientId,
            systolic: row["systolic"],
            diastolic: row["diastolic"],
            pulse: row["pulse"],
            measuredAt: measuredAt,
            source: row["source"],
            note: row["note"],
            syncStatus: row["sync_status"],
            serverId: row["server_id"]
        )
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createLocalBloodPressureReadings") { db in
            try db.create(table: "local_blood_pressure_readings", ifNotExists: true) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("client_id", .text).notNull().unique()
                table.column("systolic", .integer).notNull()
                table.column("diastolic", .integer).notNull()
                table.column("pulse", .integer)
                table.column("measured_at", .text).notNull()
                table.column("source", .text).notNull()
                table.column("note", .text)
                table.column("sync_status", .text).notNull()
                table.column("server_id", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
        }
        migrator.registerMigration("addUserIdToLocalBloodPressureReadings") { db in
            try db.alter(table: "local_blood_pressure_readings") { table in
                table.add(column: "user_id", .text).notNull().defaults(to: "")
            }
        }
        return migrator
    }
}
