//
//  BloodPressureReadingRepository.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import Foundation
import SwiftData

@MainActor
protocol BloodPressureReadingRepository {
    func save(_ reading: BloodPressureReading) throws
    func fetchLatest(userId: String) throws -> BloodPressureReading?
    func upsertRemote(_ reading: RemoteBloodPressureReading, userId: String) throws
}

@MainActor
final class SwiftDataBloodPressureReadingRepository: BloodPressureReadingRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ reading: BloodPressureReading) throws {
        modelContext.insert(reading)
        try modelContext.save()
    }

    func fetchLatest(userId: String) throws -> BloodPressureReading? {
        var descriptor = FetchDescriptor<BloodPressureReading>(
            predicate: #Predicate<BloodPressureReading> { reading in
                reading.userId == userId
            },
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    func upsertRemote(_ reading: RemoteBloodPressureReading, userId: String) throws {
        guard !userId.isEmpty else {
            return
        }

        guard reading.deletedAt == nil else {
            try deleteLocalReading(clientId: reading.clientId, userId: userId)
            return
        }

        guard
            let systolic = reading.systolic,
            let diastolic = reading.diastolic,
            let measuredAtString = reading.measuredAt,
            let measuredAt = Self.parseRemoteDate(measuredAtString)
        else {
            return
        }

        if let existing = try fetchByClientId(reading.clientId, userId: userId) {
            existing.systolic = systolic
            existing.diastolic = diastolic
            existing.pulse = reading.pulse
            existing.measuredAt = measuredAt
            existing.source = reading.source ?? existing.source
        } else {
            let localReading = BloodPressureReading(
                id: reading.clientId,
                userId: userId,
                systolic: systolic,
                diastolic: diastolic,
                pulse: reading.pulse,
                measuredAt: measuredAt,
                source: .manual
            )
            localReading.source = reading.source ?? localReading.source
            modelContext.insert(localReading)
        }

        try modelContext.save()
    }

    private func fetchByClientId(_ clientId: UUID, userId: String) throws -> BloodPressureReading? {
        var descriptor = FetchDescriptor<BloodPressureReading>(
            predicate: #Predicate<BloodPressureReading> { reading in
                reading.userId == userId && reading.id == clientId
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func deleteLocalReading(clientId: UUID, userId: String) throws {
        if let existing = try fetchByClientId(clientId, userId: userId) {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    private static func parseRemoteDate(_ value: String) -> Date? {
        fractionalISOFormatter.date(from: value) ?? standardISOFormatter.date(from: value)
    }

    private static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

@MainActor
final class MockBloodPressureReadingRepository: BloodPressureReadingRepository {
    private var readings: [BloodPressureReading]

    init(readings: [BloodPressureReading] = []) {
        self.readings = readings
    }

    func save(_ reading: BloodPressureReading) throws {
        readings.append(reading)
    }

    func fetchLatest(userId: String) throws -> BloodPressureReading? {
        readings
            .filter { $0.userId == userId }
            .sorted { $0.measuredAt > $1.measuredAt }
            .first
    }

    func upsertRemote(_ reading: RemoteBloodPressureReading, userId: String) throws {
        guard
            reading.deletedAt == nil,
            let systolic = reading.systolic,
            let diastolic = reading.diastolic,
            let measuredAtString = reading.measuredAt,
            let measuredAt = MockBloodPressureReadingRepository.parseRemoteDate(measuredAtString)
        else {
            readings.removeAll { $0.userId == userId && $0.id == reading.clientId }
            return
        }

        if let index = readings.firstIndex(where: { $0.userId == userId && $0.id == reading.clientId }) {
            readings[index].systolic = systolic
            readings[index].diastolic = diastolic
            readings[index].pulse = reading.pulse
            readings[index].measuredAt = measuredAt
            readings[index].source = reading.source ?? readings[index].source
        } else {
            let localReading = BloodPressureReading(
                id: reading.clientId,
                userId: userId,
                systolic: systolic,
                diastolic: diastolic,
                pulse: reading.pulse,
                measuredAt: measuredAt,
                source: .manual
            )
            localReading.source = reading.source ?? localReading.source
            readings.append(localReading)
        }
    }

    private static func parseRemoteDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: value)
    }
}
