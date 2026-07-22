import Foundation
import SwiftData
import Testing
@testable import hypertension

struct BloodPressureHistoryTests {
    @Test @MainActor func validationAcceptsBackendBoundaryValues() {
        let minimum = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "40",
                diastolic: "30",
                pulse: "30",
                measuredAt: Date()
            )
        )
        let maximum = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "260",
                diastolic: "180",
                pulse: "240",
                measuredAt: Date()
            )
        )

        #expect(minimum.validate())
        #expect(maximum.validate())
    }

    @Test @MainActor func validationMatchesBackendRanges() {
        let invalidCases: [(BPReadingDraft, String)] = [
            (
                BPReadingDraft(systolic: "39", diastolic: "30", measuredAt: Date()),
                "收缩压应在 40–260 mmHg 之间。"
            ),
            (
                BPReadingDraft(systolic: "261", diastolic: "80", measuredAt: Date()),
                "收缩压应在 40–260 mmHg 之间。"
            ),
            (
                BPReadingDraft(systolic: "120", diastolic: "29", measuredAt: Date()),
                "舒张压应在 30–180 mmHg 之间。"
            ),
            (
                BPReadingDraft(systolic: "200", diastolic: "181", measuredAt: Date()),
                "舒张压应在 30–180 mmHg 之间。"
            ),
            (
                BPReadingDraft(systolic: "120", diastolic: "80", pulse: "29", measuredAt: Date()),
                "心率应在 30–240 bpm 之间，或留空。"
            ),
            (
                BPReadingDraft(systolic: "120", diastolic: "80", pulse: "241", measuredAt: Date()),
                "心率应在 30–240 bpm 之间，或留空。"
            )
        ]

        for (draft, expectedMessage) in invalidCases {
            let viewModel = BPConfirmReadingViewModel(draft: draft)
            #expect(!viewModel.validate())
            #expect(viewModel.errorMessage == expectedMessage)
        }
    }

    @Test @MainActor func threeRecordedDaysProduceThreeTrendPointsNotSeven() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let readings = [
            makeReading(systolic: 120, diastolic: 80, date: today),
            makeReading(systolic: 130, diastolic: 90, date: today.addingTimeInterval(3600)),
            makeReading(systolic: 125, diastolic: 82, date: calendar.date(byAdding: .day, value: -2, to: today)!),
            makeReading(systolic: 118, diastolic: 78, date: calendar.date(byAdding: .day, value: -6, to: today)!)
        ]

        let points = BloodPressureHomeViewModel().trendPoints(from: readings)

        #expect(points.count == 3)
        #expect(points.last?.systolic == 125)
        #expect(points.last?.diastolic == 85)
    }

    @Test @MainActor func repositoryUpdatesDeletesAndKeepsRemoteIdentifier() throws {
        let schema = Schema([BloodPressureReading.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SwiftDataBloodPressureReadingRepository(modelContext: container.mainContext)
        let reading = makeReading(systolic: 128, diastolic: 82, date: Date())

        try repository.save(reading)
        try repository.update(
            reading,
            with: BPReadingDraft(
                systolic: "132",
                diastolic: "84",
                pulse: "70",
                measuredAt: reading.measuredAt
            )
        )

        #expect(reading.systolic == 132)
        #expect(reading.diastolic == 84)
        #expect(reading.pulse == 70)

        let remote = RemoteBloodPressureReading(
            id: "server-reading-1",
            clientId: reading.id,
            systolic: 133,
            diastolic: 85,
            pulse: 71,
            measuredAt: ISO8601DateFormatter().string(from: reading.measuredAt),
            source: "manual",
            deletedAt: nil
        )
        try repository.upsertRemote(remote, userId: reading.userId)

        #expect(reading.serverId == "server-reading-1")
        #expect(reading.systolic == 133)

        try repository.deleteAll(userId: reading.userId)
        #expect(try repository.fetchLatest(userId: reading.userId) == nil)
    }

    @Test @MainActor func failedSyncReturnsReadingToPendingQueue() throws {
        let store = GRDBLocalReadingStore.shared
        let userId = "bp-sync-retry-\(UUID().uuidString)"
        let clientId = UUID()
        defer { try? store.remove(clientId: clientId, userId: userId) }

        let draft = BPReadingDraft(
            systolic: "128",
            diastolic: "82",
            pulse: "72",
            measuredAt: Date()
        )
        try store.upsertPending(draft, userId: userId, clientId: clientId)
        try store.markSyncing(clientIds: [clientId])
        #expect(try store.pendingReadings(userId: userId).isEmpty)

        try store.markSyncFailed(clientIds: [clientId])
        #expect(try store.pendingReadings(userId: userId).map(\.clientId) == [clientId])
    }

    @Test @MainActor func queuedEditRetainsKnownServerIdentifier() throws {
        let store = GRDBLocalReadingStore.shared
        let userId = "bp-edit-server-id-\(UUID().uuidString)"
        let clientId = UUID()
        defer { try? store.remove(clientId: clientId, userId: userId) }

        let draft = BPReadingDraft(systolic: "128", diastolic: "82", measuredAt: Date())
        try store.upsertPending(draft, userId: userId, clientId: clientId)
        try store.markSynced(clientId: clientId, serverId: "server-id")
        try store.upsertPending(draft, userId: userId, clientId: clientId)

        #expect(try store.serverId(clientId: clientId, userId: userId) == "server-id")
        #expect(try store.isPending(clientId: clientId, userId: userId))
    }

    @MainActor
    private func makeReading(systolic: Int, diastolic: Int, date: Date) -> BloodPressureReading {
        BloodPressureReading(
            userId: "bp-history-test-user",
            systolic: systolic,
            diastolic: diastolic,
            measuredAt: date,
            source: .manual
        )
    }
}
