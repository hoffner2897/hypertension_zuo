//
//  BloodPressureHomeViewModel.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class BloodPressureHomeViewModel: ObservableObject {
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var interpretation: BPInterpretation?
    @Published private(set) var isLoadingInterpretation = false
    @Published private(set) var interpretationErrorMessage: String?
    @Published private(set) var historyActionErrorMessage: String?
    @Published private(set) var isUpdatingHistory = false

    private let localReadingStore = GRDBLocalReadingStore.shared
    private let apiService = BloodPressureReadingAPIService()

    var emptyDraft: BPReadingDraft {
        BPReadingDraft()
    }

    func trendPoints(from readings: [BloodPressureReading]) -> [BloodPressureTrendPoint] {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: readings) { reading in
            calendar.startOfDay(for: reading.measuredAt)
        }

        return groupedByDay
            .compactMap { day, readings -> BloodPressureTrendPoint? in
                guard !readings.isEmpty else {
                    return nil
                }

                return BloodPressureTrendPoint(
                    day: Self.dayLabel(for: day),
                    measuredAt: day,
                    systolic: Self.average(readings.map(\.systolic)),
                    diastolic: Self.average(readings.map(\.diastolic))
                )
            }
            .sorted { $0.measuredAt < $1.measuredAt }
            .suffix(7)
            .map { $0 }
    }

    func syncPendingReadings(userId: String) async {
        guard !userId.isEmpty else {
            syncStatusMessage = nil
            return
        }

        var attemptedClientIds: [UUID] = []
        do {
            let pending = try localReadingStore.pendingReadings(userId: userId)
            guard !pending.isEmpty else {
                syncStatusMessage = nil
                return
            }

            attemptedClientIds = pending.map(\.clientId)
            try localReadingStore.markSyncing(clientIds: attemptedClientIds)
            let response = try await apiService.sync(readings: pending)

            for reading in response.readings {
                try localReadingStore.markSynced(clientId: reading.clientId, serverId: reading.id)
            }

            syncStatusMessage = "已同步 \(response.readings.count) 条本地读数。"
        } catch {
            try? localReadingStore.markSyncFailed(clientIds: attemptedClientIds)
            syncStatusMessage = "有读数等待联网后同步。"
        }
    }

    func refreshRemoteReadings(userId: String, repository: any BloodPressureReadingRepository) async {
        guard !userId.isEmpty else {
            return
        }

        do {
            let response = try await apiService.list(limit: 100, includeDeleted: true)
            for reading in response.readings {
                try repository.upsertRemote(reading, userId: userId)
            }

            if !response.readings.isEmpty {
                syncStatusMessage = "已更新服务器上的 \(response.readings.count) 条读数。"
            }
        } catch {
            if syncStatusMessage == nil {
                syncStatusMessage = "暂时无法更新服务器读数。"
            }
        }
    }

    func refreshInterpretation(reading: BloodPressureReading?, recentReadings: [BloodPressureReading]) async {
        guard let reading else {
            interpretation = nil
            interpretationErrorMessage = nil
            isLoadingInterpretation = false
            return
        }

        isLoadingInterpretation = true
        defer { isLoadingInterpretation = false }

        do {
            let response = try await apiService.interpret(
                reading: BPInterpretationReadingSnapshot(reading),
                recentReadings: recentReadings.map(BPInterpretationReadingSnapshot.init)
            )
            interpretation = response.interpretation
            interpretationErrorMessage = nil
        } catch {
            interpretation = BPInterpretationRuleFallback.makeInterpretation(from: reading)
            interpretationErrorMessage = "暂时无法获取 AI 解释，已显示本地规则说明。"
        }
    }

    func deleteReading(
        _ reading: BloodPressureReading,
        userId: String,
        repository: any BloodPressureReadingRepository
    ) async -> Bool {
        guard !isUpdatingHistory else {
            return false
        }

        isUpdatingHistory = true
        defer { isUpdatingHistory = false }

        do {
            let isPending = try localReadingStore.isPending(clientId: reading.id, userId: userId)
            let knownServerId = try (
                reading.serverId ?? localReadingStore.serverId(clientId: reading.id, userId: userId)
            )
            if !isPending || knownServerId != nil {
                let remoteId: String?
                if let serverId = knownServerId {
                    remoteId = serverId
                } else {
                    remoteId = try await apiService.find(clientId: reading.id)?.id
                }

                if let remoteId {
                    try await apiService.delete(id: remoteId)
                }
            }

            try repository.delete(reading)
            try localReadingStore.remove(clientId: reading.id, userId: userId)
            historyActionErrorMessage = nil
            return true
        } catch {
            historyActionErrorMessage = "暂时无法删除这条读数，请联网后重试。"
            return false
        }
    }

    func clearHistoryActionError() {
        historyActionErrorMessage = nil
    }

    private static func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else {
            return 0
        }

        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private static func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter.string(from: date)
    }
}

enum BPInterpretationRuleFallback {
    static func makeInterpretation(from reading: BloodPressureReading) -> BPInterpretation {
        let category: BPInterpretationCategory
        if reading.systolic >= 180 || reading.diastolic >= 120 {
            category = .urgent
        } else if reading.systolic >= 135 || reading.diastolic >= 85 {
            category = .highHome
        } else if reading.systolic >= 120 || reading.diastolic >= 80 {
            category = .borderline
        } else if reading.systolic < 90 || reading.diastolic < 60 {
            category = .low
        } else {
            category = .normal
        }

        switch category {
        case .urgent:
            return BPInterpretation(
                category: category,
                severity: .urgent,
                bloodPressureSituation: ["本次为 \(reading.systolic)/\(reading.diastolic) mmHg，达到需要高度重视的范围。"],
                reasons: ["本次读数达到需要高度重视的范围。"],
                nextSteps: ["安静休息后立即规范复测。", "如仍处于该范围或伴有明显不适，请立即寻求急诊帮助。"],
                safetyNote: defaultSafetyNote,
                disclaimer: disclaimer
            )
        case .highHome:
            return BPInterpretation(
                category: category,
                severity: .repeat,
                bloodPressureSituation: ["本次为 \(reading.systolic)/\(reading.diastolic) mmHg，超过家庭血压参考阈值 135/85 mmHg。"],
                reasons: ["家庭血压超过 135/85 mmHg 时，建议复测并观察平均值。"],
                nextSteps: ["安静坐位休息 5 分钟后规范复测。", "连续几天记录并观察家庭平均值。"],
                safetyNote: defaultSafetyNote,
                disclaimer: disclaimer
            )
        case .borderline:
            return BPInterpretation(
                category: category,
                severity: .watch,
                bloodPressureSituation: ["本次为 \(reading.systolic)/\(reading.diastolic) mmHg，未达到家庭偏高阈值，但接近诊室正常高值范围。"],
                reasons: ["本次读数接近偏高范围，可能受休息、压力或测量条件影响。"],
                nextSteps: ["在相同条件下继续记录。", "结合接下来几天的平均值观察变化。"],
                safetyNote: defaultSafetyNote,
                disclaimer: disclaimer
            )
        case .low:
            return BPInterpretation(
                category: category,
                severity: .watch,
                bloodPressureSituation: ["本次为 \(reading.systolic)/\(reading.diastolic) mmHg，低于常见参考范围。"],
                reasons: ["本次读数低于常见参考范围。"],
                nextSteps: ["在相同条件下规范复测。", "如有头晕、乏力或晕厥等不适，请及时寻求医疗帮助。"],
                safetyNote: defaultSafetyNote,
                disclaimer: disclaimer
            )
        case .normal, .insufficientData:
            return BPInterpretation(
                category: .normal,
                severity: .reassuring,
                bloodPressureSituation: ["本次为 \(reading.systolic)/\(reading.diastolic) mmHg，处于常见家庭血压参考范围。"],
                reasons: ["本次家庭血压读数在常见正常范围内。"],
                nextSteps: ["继续保持规律记录即可。"],
                safetyNote: defaultSafetyNote,
                disclaimer: disclaimer
            )
        }
    }

    private static let defaultSafetyNote = "如出现胸痛、气短、剧烈头痛、视物异常、肢体无力、意识异常或晕厥等症状，请及时寻求医疗帮助。"
    private static let disclaimer = "此解释仅用于健康记录和趋势理解，不构成诊断，也不能替代医生建议或用药调整。"
}

@Model
final class BloodPressureReading {
    var id: UUID
    var serverId: String?
    var userId: String = ""
    var systolic: Int
    var diastolic: Int
    var pulse: Int?
    var measuredAt: Date
    var source: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        userId: String,
        systolic: Int,
        diastolic: Int,
        pulse: Int? = nil,
        measuredAt: Date,
        source: BPReadingSource,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.serverId = serverId
        self.userId = userId
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.measuredAt = measuredAt
        self.source = source.rawValue
        self.createdAt = createdAt
    }
}

struct BloodPressureTrendPoint: Identifiable, Hashable {
    let id = UUID()
    let day: String
    let measuredAt: Date
    let systolic: Int
    let diastolic: Int
}

struct BPReadingDraft: Hashable {
    var source: BPReadingSource = .manual
    var systolic: String = ""
    var diastolic: String = ""
    var pulse: String = ""
    var measuredAt: Date = Date()
}

enum BPReadingSource: String, Hashable {
    case cameraRecognition
    case manual

    var label: String {
        switch self {
        case .cameraRecognition:
            "拍照识别"
        case .manual:
            "手动输入"
        }
    }

    static func fromStoredValue(_ value: String) -> BPReadingSource {
        switch value {
        case "cameraRecognition", "camera_mock", "camera_ocr":
            return .cameraRecognition
        default:
            return .manual
        }
    }
}

extension BPReadingDraft {
    @MainActor
    init(reading: BloodPressureReading) {
        source = BPReadingSource.fromStoredValue(reading.source)
        systolic = String(reading.systolic)
        diastolic = String(reading.diastolic)
        pulse = reading.pulse.map(String.init) ?? ""
        measuredAt = reading.measuredAt
    }
}
