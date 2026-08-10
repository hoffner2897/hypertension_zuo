import Foundation
import Testing
@testable import hypertension

struct MealPhotoStoreTests {
    @Test func photoPersistsLocallyForTheMatchingUserRecordAndVersion() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meal-photo-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MealPhotoStore(rootDirectory: root)
        let expected = Data([0xFF, 0xD8, 0xFF, 0xD9])

        try store.save(
            expected,
            userId: "user-a",
            recordId: "meal-a",
            recordVersion: "2026-08-10T12:00:00.000Z"
        )

        #expect(store.data(
            userId: "user-a",
            recordId: "meal-a",
            recordVersion: "2026-08-10T12:00:00.000Z"
        ) == expected)
        #expect(store.data(
            userId: "user-b",
            recordId: "meal-a",
            recordVersion: "2026-08-10T12:00:00.000Z"
        ) == nil)
    }

    @Test func aNewAnalysisVersionReplacesTheOldLocalPhoto() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meal-photo-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MealPhotoStore(rootDirectory: root)

        try store.save(Data([1]), userId: "user-a", recordId: "meal-a", recordVersion: "version-1")
        try store.save(Data([2]), userId: "user-a", recordId: "meal-a", recordVersion: "version-2")

        #expect(store.data(userId: "user-a", recordId: "meal-a", recordVersion: "version-1") == nil)
        #expect(store.data(userId: "user-a", recordId: "meal-a", recordVersion: "version-2") == Data([2]))
    }

    @Test func deletingAnAccountRemovesOnlyThatUsersLocalMealPhotos() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meal-photo-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MealPhotoStore(rootDirectory: root)

        try store.save(Data([1]), userId: "user-a", recordId: "meal-a", recordVersion: "v1")
        try store.save(Data([2]), userId: "user-b", recordId: "meal-b", recordVersion: "v1")
        try store.removeAll(userId: "user-a")

        #expect(store.data(userId: "user-a", recordId: "meal-a", recordVersion: "v1") == nil)
        #expect(store.data(userId: "user-b", recordId: "meal-b", recordVersion: "v1") == Data([2]))
    }
}
