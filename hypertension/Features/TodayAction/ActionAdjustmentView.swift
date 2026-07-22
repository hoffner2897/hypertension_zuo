import Combine
import SwiftData
import SwiftUI

struct ActionAdjustDemoView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding private var items: [TodayActionItem]
    @Query private var savedReadings: [BloodPressureReading]

    private let userId: String
    private let readingService = BloodPressureReadingAPIService()

    @State private var path: [ActionAdjustmentRoute] = []
    @StateObject private var viewModel = ActionAdjustmentViewModel()

    init(items: Binding<[TodayActionItem]>, userId: String) {
        self._items = items
        self.userId = userId
        self._savedReadings = Query(
            filter: #Predicate<BloodPressureReading> { reading in
                reading.userId == userId
            },
            sort: \BloodPressureReading.measuredAt,
            order: .reverse
        )
    }

    private var latestReading: BloodPressureReading? {
        savedReadings.first
    }

    private var entries: [ActionAdjustmentEntry] {
        ActionAdjustmentEntry.makeEntries(from: items)
    }

    private var suggestionRefreshKey: String {
        items
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                [
                    $0.id.uuidString,
                    $0.title,
                    $0.status.rawValue,
                    String(Int($0.scheduledStartAt.timeIntervalSince1970)),
                    String($0.durationMinutes)
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                        AdjustmentPageTitle()
                        todayStatusCard
                        actionListCard
                        trendSuggestionsCard
                    }
                    .padding(DSTheme.Spacing.large)
                    .padding(.bottom, 150)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ActionAdjustmentRoute.self) { route in
                if let targetItems = items(for: route.target), !targetItems.isEmpty {
                    ActionAdjustmentEditorPage(
                        target: route.target,
                        items: targetItems,
                        suggestion: route.suggestion
                    ) { adjustedItems in
                        apply(adjustedItems)
                        if !path.isEmpty {
                            path.removeLast()
                        }
                    }
                }
            }
            .task {
                await refreshRemoteReadings()
            }
            .task(id: suggestionRefreshKey) {
                await viewModel.refresh(items: items, userId: userId)
            }
        }
    }

    private var todayStatusCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Label("今日状态", systemImage: "waveform.path.ecg")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                HStack(spacing: DSTheme.Spacing.medium) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .frame(width: 68, height: 68)
                        .background(DSTheme.Color.primarySoft.opacity(0.7))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("血压")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DSTheme.Color.textSecondary)

                        if let latestReading {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("\(latestReading.systolic)/\(latestReading.diastolic)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                                Text("mmHg")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }

                            Text(Self.measurementTimeFormatter.string(from: latestReading.measuredAt))
                                .font(.caption)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        } else {
                            Text("暂无读数")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(DSTheme.Color.textPrimary)

                            Text("记录后会在这里显示最新血压")
                                .font(.caption)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var actionListCard: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                Text("今天还没有可显示的行动")
                    .font(.subheadline)
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(DSTheme.Spacing.large)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    AdjustmentEntryRow(entry: entry) {
                        path.append(ActionAdjustmentRoute(target: entry.target, suggestion: nil))
                    }

                    if index < entries.count - 1 {
                        Divider()
                            .overlay(DSTheme.Color.border)
                            .padding(.horizontal, DSTheme.Spacing.medium)
                    }
                }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: DSTheme.cardShadow, radius: 14, x: 0, y: 7)
    }

    private var trendSuggestionsCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                HStack(alignment: .firstTextBaseline, spacing: DSTheme.Spacing.small) {
                    Label("趋势调整", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                    Spacer(minLength: 8)

                    Text(viewModel.evidenceDays > 1 ? "基于近\(viewModel.evidenceDays)天记录" : "基于今日进度生成建议")
                        .font(.caption2)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                if viewModel.isLoading && viewModel.suggestions.isEmpty {
                    HStack(spacing: DSTheme.Spacing.small) {
                        ProgressView()
                        Text("正在分析当前行动…")
                            .font(.subheadline)
                            .foregroundStyle(DSTheme.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DSTheme.Spacing.small)
                } else if viewModel.suggestions.isEmpty {
                    Label(
                        viewModel.dataNote ?? "当前没有需要调整的行动。",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(DSTheme.Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSTheme.Color.primarySoft.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ForEach(viewModel.suggestions) { suggestion in
                        Button {
                            guard let target = target(for: suggestion) else {
                                return
                            }
                            path.append(ActionAdjustmentRoute(target: target, suggestion: suggestion))
                        } label: {
                            HStack(spacing: DSTheme.Spacing.medium) {
                                Image(systemName: suggestion.kind.systemImage)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.primary)
                                    .frame(width: 46, height: 46)
                                    .background(DSTheme.Color.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                                Text(suggestion.message)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)

                                if suggestion.targetActionId != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(DSTheme.Color.primary)
                                }
                            }
                            .padding(DSTheme.Spacing.medium)
                            .background(.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(DSTheme.Color.border, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(suggestion.targetActionId == nil)
                    }
                }

                Label("建议仅用于优化行动安排，不构成诊断或治疗建议。", systemImage: "info.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
    }

    private func target(for suggestion: ActionTrendSuggestion) -> ActionAdjustmentTarget? {
        guard
            let targetID = suggestion.targetActionId,
            let item = items.first(where: { $0.id == targetID }),
            item.status != .completed
        else {
            return nil
        }

        return ActionAdjustmentTarget(item: item)
    }

    private func items(for target: ActionAdjustmentTarget) -> [TodayActionItem]? {
        switch target {
        case .bloodPressure:
            return items.filter { $0.type == .bpRecheck }.sortedByStartTime()
        case .diet:
            return items.filter { $0.type == .diet }.sortedByStartTime()
        case .single(let id):
            return items.first(where: { $0.id == id }).map { [$0] }
        }
    }

    private func apply(_ adjustedItems: [TodayActionItem]) {
        let adjustmentTimestamp = Date()
        for adjustedItem in adjustedItems {
            guard let index = items.firstIndex(where: { $0.id == adjustedItem.id }) else {
                continue
            }
            var stampedItem = adjustedItem
            stampedItem.clientUpdatedAt = adjustmentTimestamp
            items[index] = stampedItem
        }

        items.sort { $0.scheduledStartAt < $1.scheduledStartAt }
        for index in items.indices {
            items[index].sortOrder = index
        }
    }

    private func refreshRemoteReadings() async {
        guard !userId.isEmpty else {
            return
        }

        do {
            let response = try await readingService.list(limit: 20)
            let repository = SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
            for reading in response.readings {
                try repository.upsertRemote(reading, userId: userId)
            }
        } catch {
            // The local SwiftData reading remains the source of truth while offline.
        }
    }

    private static let measurementTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private struct AdjustmentPageTitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("行动调整")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

            Text("Action Adjustment")
                .font(.subheadline)
                .foregroundStyle(DSTheme.Color.textSecondary)
        }
    }
}

private struct AdjustmentEntryRow: View {
    let entry: ActionAdjustmentEntry
    let onAdjust: () -> Void

    var body: some View {
        HStack(spacing: DSTheme.Spacing.medium) {
            AdjustmentArtwork(item: entry.items.first, fallbackSystemImage: entry.systemImage)
                .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                Label(entry.scheduleText, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if entry.hasAdjustableItems {
                VStack(spacing: 8) {
                    Text("可调整")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DSTheme.Color.success)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DSTheme.Color.success.opacity(0.10))
                        .clipShape(Capsule())

                    Button(action: onAdjust) {
                        HStack(spacing: 5) {
                            Text("调整")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .overlay {
                            Capsule()
                                .stroke(DSTheme.Color.primary.opacity(0.65), lineWidth: 1.2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("已完成")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(DSTheme.Color.border.opacity(0.55))
                    .clipShape(Capsule())
            }
        }
        .padding(DSTheme.Spacing.medium)
    }
}

private struct AdjustmentArtwork: View {
    let item: TodayActionItem?
    let fallbackSystemImage: String

    var body: some View {
        Group {
            if let assetName = item?.timelineArtworkAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DSTheme.Color.primarySoft.opacity(0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ActionAdjustmentRoute: Hashable {
    let target: ActionAdjustmentTarget
    let suggestion: ActionTrendSuggestion?
}

private enum ActionAdjustmentTarget: Hashable {
    case bloodPressure
    case diet
    case single(UUID)

    init(item: TodayActionItem) {
        switch item.type {
        case .bpRecheck:
            self = .bloodPressure
        case .diet:
            self = .diet
        default:
            self = .single(item.id)
        }
    }
}

private struct ActionAdjustmentEntry: Identifiable {
    let target: ActionAdjustmentTarget
    let title: String
    let items: [TodayActionItem]
    let systemImage: String

    var id: String {
        switch target {
        case .bloodPressure:
            "blood-pressure"
        case .diet:
            "diet"
        case .single(let id):
            id.uuidString
        }
    }

    var scheduleText: String {
        switch target {
        case .bloodPressure, .diet:
            return items.map(\.startTimeText).joined(separator: "  |  ")
        case .single:
            guard let item = items.first else { return "" }
            return "\(item.startTimeText)  |  \(item.durationMinutes)分钟"
        }
    }

    var hasAdjustableItems: Bool {
        items.contains { $0.status != .completed }
    }

    static func makeEntries(from items: [TodayActionItem]) -> [ActionAdjustmentEntry] {
        let sortedItems = items.sortedByStartTime()
        var entries: [ActionAdjustmentEntry] = []

        let bloodPressureItems = sortedItems.filter { $0.type == .bpRecheck }
        if !bloodPressureItems.isEmpty {
            entries.append(
                ActionAdjustmentEntry(
                    target: .bloodPressure,
                    title: "血压测量",
                    items: bloodPressureItems,
                    systemImage: "heart.text.square.fill"
                )
            )
        }

        let dietItems = sortedItems.filter { $0.type == .diet }
        if !dietItems.isEmpty {
            entries.append(
                ActionAdjustmentEntry(
                    target: .diet,
                    title: "饮食建议",
                    items: dietItems,
                    systemImage: "fork.knife"
                )
            )
        }

        for item in sortedItems where item.type != .bpRecheck && item.type != .diet {
            entries.append(
                ActionAdjustmentEntry(
                    target: .single(item.id),
                    title: item.title,
                    items: [item],
                    systemImage: item.type.systemImage
                )
            )
        }

        return entries
    }
}

@MainActor
private final class ActionAdjustmentViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var suggestions: [ActionTrendSuggestion] = []
    @Published private(set) var dataNote: String?
    @Published private(set) var evidenceDays = 0

    private let service = ActionAdjustmentAPIService()

    func refresh(items: [TodayActionItem], userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.fetchTrendSuggestions(items: items, userId: userId)
            suggestions = response.suggestions
            dataNote = response.dataNote
            evidenceDays = response.evidenceDays
        } catch {
            let fallback = ActionTrendSuggestion.localFallback(for: items, now: Date())
            suggestions = fallback.suggestions
            dataNote = fallback.dataNote
            evidenceDays = items.isEmpty ? 0 : 1
        }
    }
}

private struct ActionAdjustmentAPIService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTrendSuggestions(items: [TodayActionItem], userId: String) async throws -> ActionTrendSuggestionResponse {
        let now = Date()
        return try await apiClient.post(
            "/action-adjustments/trend-suggestions",
            body: ActionTrendSuggestionRequest(items: items, recent: ActionHistoryStore.recent(userId: userId), now: now),
            requiresAuth: true
        )
    }
}

private struct ActionTrendSuggestionRequest: Encodable {
    let now: String
    let timeZone: String
    let todayActions: [ActionTrendActionSnapshot]
    let recentActions: [ActionTrendActionSnapshot]

    init(items: [TodayActionItem], recent: [StoredActionObservation], now: Date) {
        self.now = Self.formatter.string(from: now)
        self.timeZone = TimeZone.current.identifier
        self.todayActions = items.map { ActionTrendActionSnapshot(item: $0, now: now) }
        self.recentActions = recent.prefix(100).map { observation in
            ActionTrendActionSnapshot(observation)
        }
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ActionTrendActionSnapshot: Encodable {
    let id: UUID
    let type: String
    let title: String
    let scheduledStartAt: String
    let durationMinutes: Int
    let status: String
    let completedAt: String?

    init(item: TodayActionItem, now: Date) {
        id = item.id
        type = item.type.apiType
        title = item.title
        scheduledStartAt = Self.formatter.string(from: item.scheduledStartAt)
        durationMinutes = item.durationMinutes
        status = item.effectiveStatus(now: now).apiValue
        completedAt = item.completedAt.map { Self.formatter.string(from: $0) }
    }

    init(_ observation: StoredActionObservation) {
        id = observation.id
        type = observation.type
        title = observation.title
        scheduledStartAt = Self.formatter.string(from: observation.scheduledStartAt)
        durationMinutes = observation.durationMinutes
        status = observation.normalizedStatus
        completedAt = observation.completedAt.map { Self.formatter.string(from: $0) }
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ActionTrendSuggestionResponse: Decodable {
    let status: String
    let source: String
    let evidenceDays: Int
    let suggestions: [ActionTrendSuggestion]
    let dataNote: String?
    let disclaimer: String
}

private struct ActionTrendSuggestion: Decodable, Identifiable, Hashable {
    let targetActionId: UUID?
    let kind: ActionTrendSuggestionKind
    let message: String
    let proposedStartTime: String?
    let proposedDurationMinutes: Int?
    let proposedExerciseName: String?

    var id: String {
        [targetActionId?.uuidString ?? "general", kind.rawValue, message].joined(separator: "-")
    }

    static func localFallback(for items: [TodayActionItem], now: Date) -> (suggestions: [ActionTrendSuggestion], dataNote: String?) {
        let missedItems = items
            .filter { $0.status != .completed && $0.effectiveStatus(now: now) == .missed }
            .sortedByStartTime()

        let suggestions = missedItems.prefix(2).map { item in
            let kind: ActionTrendSuggestionKind = item.type == .walk || item.type == .custom ? .shorten : .reschedule
            let message: String
            let proposedDuration: Int?

            if kind == .shorten {
                message = "今天的\(item.title)已错过，可尝试缩短时长或重新安排。"
                proposedDuration = min(item.durationMinutes, 10)
            } else {
                message = "今天的\(item.title)已错过，可调整到更方便的时间。"
                proposedDuration = nil
            }

            return ActionTrendSuggestion(
                targetActionId: item.id,
                kind: kind,
                message: message,
                proposedStartTime: nil,
                proposedDurationMinutes: proposedDuration,
                proposedExerciseName: nil
            )
        }

        let dataNote = suggestions.isEmpty ? "行动记录还在积累，完成几次后再提供更具体的建议。" : nil
        return (Array(suggestions), dataNote)
    }
}

private enum ActionTrendSuggestionKind: String, Decodable, Hashable {
    case reschedule
    case shorten
    case switchExercise = "switch_exercise"
    case resolveConflict = "resolve_conflict"
    case keepPlan = "keep_plan"

    var systemImage: String {
        switch self {
        case .reschedule:
            "clock.arrow.circlepath"
        case .shorten:
            "timer"
        case .switchExercise:
            "figure.walk.motion"
        case .resolveConflict:
            "calendar.badge.exclamationmark"
        case .keepPlan:
            "checkmark.circle"
        }
    }
}

private extension TodayActionType {
    var apiType: String {
        switch self {
        case .bpRecheck:
            "blood_pressure"
        case .diet:
            "diet"
        case .walk:
            "exercise"
        case .rest, .hydration, .sleep, .custom:
            "other"
        }
    }
}

private extension TodayActionStatus {
    var apiValue: String {
        switch self {
        case .pending:
            "pending"
        case .inProgress:
            "in_progress"
        case .completed:
            "completed"
        case .skipped:
            "skipped"
        case .missed:
            "missed"
        }
    }
}

private extension Array where Element == TodayActionItem {
    func sortedByStartTime() -> [TodayActionItem] {
        sorted {
            if $0.scheduledStartAt == $1.scheduledStartAt {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.scheduledStartAt < $1.scheduledStartAt
        }
    }
}

private struct ActionAdjustmentEditorPage: View {
    @Environment(\.dismiss) private var dismiss

    let target: ActionAdjustmentTarget
    let items: [TodayActionItem]
    let suggestion: ActionTrendSuggestion?
    let onSave: ([TodayActionItem]) -> Void

    @ViewBuilder
    var body: some View {
        switch target {
        case .bloodPressure:
            GroupedTimeAdjustmentEditor(
                kind: .bloodPressure,
                items: items,
                suggestion: suggestion,
                onBack: { dismiss() },
                onSave: onSave
            )
        case .diet:
            GroupedTimeAdjustmentEditor(
                kind: .diet,
                items: items,
                suggestion: suggestion,
                onBack: { dismiss() },
                onSave: onSave
            )
        case .single:
            if let item = items.first {
                MovementAdjustmentEditor(
                    item: item,
                    suggestion: suggestion,
                    onBack: { dismiss() },
                    onSave: { onSave([$0]) }
                )
            }
        }
    }
}

struct TodayActionAdjustView: View {
    let item: TodayActionItem
    let onSave: (TodayActionItem) -> Void

    var body: some View {
        ActionAdjustmentEditorPage(
            target: ActionAdjustmentTarget(item: item),
            items: [item],
            suggestion: nil
        ) { adjustedItems in
            guard let adjustedItem = adjustedItems.first else {
                return
            }
            onSave(adjustedItem)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private enum GroupedAdjustmentKind: Hashable {
    case bloodPressure
    case diet

    var title: String {
        switch self {
        case .bloodPressure:
            "血压测量"
        case .diet:
            "饮食建议"
        }
    }

    var systemImage: String {
        switch self {
        case .bloodPressure:
            "heart.text.square.fill"
        case .diet:
            "fork.knife"
        }
    }

    var contentText: String {
        switch self {
        case .bloodPressure:
            "血压测量"
        case .diet:
            "饮食建议"
        }
    }
}

private struct GroupedTimeAdjustmentEditor: View {
    let kind: GroupedAdjustmentKind
    let originalItems: [TodayActionItem]
    let suggestion: ActionTrendSuggestion?
    let onBack: () -> Void
    let onSave: ([TodayActionItem]) -> Void

    @State private var draftItems: [TodayActionItem]

    init(
        kind: GroupedAdjustmentKind,
        items: [TodayActionItem],
        suggestion: ActionTrendSuggestion?,
        onBack: @escaping () -> Void,
        onSave: @escaping ([TodayActionItem]) -> Void
    ) {
        self.kind = kind
        self.originalItems = items.sortedByStartTime()
        self.suggestion = suggestion
        self.onBack = onBack
        self.onSave = onSave

        var initialItems = items.sortedByStartTime()
        if
            let suggestion,
            let targetID = suggestion.targetActionId,
            let proposedTime = suggestion.proposedStartTime,
            let index = initialItems.firstIndex(where: { $0.id == targetID && $0.status != .completed }),
            let proposedDate = AdjustmentClock.date(from: proposedTime, anchoredTo: initialItems[index].scheduledStartAt)
        {
            initialItems[index].scheduledStartAt = proposedDate
            initialItems[index].scheduledEndAt = Calendar.current.date(
                byAdding: .minute,
                value: initialItems[index].durationMinutes,
                to: proposedDate
            ) ?? proposedDate
        }
        self._draftItems = State(initialValue: initialItems)
    }

    private var changedItemIDs: Set<UUID> {
        Set(draftItems.compactMap { draft in
            guard
                let original = originalItems.first(where: { $0.id == draft.id }),
                !AdjustmentClock.isSameMinute(original.scheduledStartAt, draft.scheduledStartAt)
            else {
                return nil
            }
            return draft.id
        })
    }

    private var changedItems: [TodayActionItem] {
        draftItems.filter { changedItemIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                    AdjustmentDetailHeader(onBack: onBack)
                    groupedOriginalPlanCard
                    groupedTimeSelectionCard

                    if !changedItems.isEmpty {
                        GroupedAdjustmentSummary(
                            kind: kind,
                            originalItems: originalItems,
                            changedItems: changedItems
                        )
                    }
                }
                .padding(DSTheme.Spacing.large)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdjustmentConfirmBar(isDisabled: changedItems.isEmpty) {
                onSave(savedItems())
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var groupedOriginalPlanCard: some View {
        DSCard {
            HStack(spacing: DSTheme.Spacing.medium) {
                AdjustmentArtwork(
                    item: originalItems.first,
                    fallbackSystemImage: kind.systemImage
                )
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(originalItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Image(systemName: scheduleIcon(for: item, index: index))
                                .foregroundStyle(DSTheme.Color.primary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                                    Text(item.status == .completed ? "已完成" : "原计划")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(item.status == .completed ? DSTheme.Color.textSecondary : DSTheme.Color.primary)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(DSTheme.Color.primarySoft.opacity(0.7))
                                        .clipShape(Capsule())
                                }

                                Label(item.startTimeText, systemImage: "clock")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }
                        }
                        .padding(.vertical, 9)

                        if index < originalItems.count - 1 {
                            Divider()
                                .overlay(DSTheme.Color.border)
                        }
                    }
                }
            }
        }
    }

    private var groupedTimeSelectionCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Text("重新选择开始时间")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                ForEach(draftItems.indices, id: \.self) { index in
                    GroupedTimeMenuRow(
                        title: draftItems[index].title,
                        systemImage: scheduleIcon(for: draftItems[index], index: index),
                        selectedTime: draftItems[index].startTimeText,
                        options: AdjustmentClock.options(including: draftItems[index].scheduledStartAt),
                        isLocked: originalItems[index].status == .completed
                    ) { timeText in
                        updateTime(at: index, to: timeText)
                    }
                }

                if originalItems.contains(where: { $0.status == .completed }) {
                    Label("已完成的行动会保留原计划，不能再次调整。", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }
            }
        }
    }

    private func updateTime(at index: Int, to timeText: String) {
        guard
            draftItems.indices.contains(index),
            originalItems[index].status != .completed,
            let date = AdjustmentClock.date(from: timeText, anchoredTo: draftItems[index].scheduledStartAt)
        else {
            return
        }

        draftItems[index].scheduledStartAt = date
        draftItems[index].scheduledEndAt = Calendar.current.date(
            byAdding: .minute,
            value: draftItems[index].durationMinutes,
            to: date
        ) ?? date
    }

    private func savedItems() -> [TodayActionItem] {
        draftItems.map { draft in
            guard
                let original = originalItems.first(where: { $0.id == draft.id }),
                original.status != .completed,
                changedItemIDs.contains(draft.id)
            else {
                return originalItems.first(where: { $0.id == draft.id }) ?? draft
            }

            var updated = draft
            updated.status = .pending
            updated.displayStatus = .pending
            updated.completedAt = nil
            return updated
        }
    }

    private func scheduleIcon(for item: TodayActionItem, index: Int) -> String {
        if kind == .bloodPressure {
            return index == 0 ? "sunrise.fill" : "moon.stars.fill"
        }

        if item.title.contains("早餐") {
            return "sunrise.fill"
        }
        if item.title.contains("午餐") {
            return "sun.max.fill"
        }
        return "moon.stars.fill"
    }
}

private struct AdjustmentDetailHeader: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                    .frame(width: 38, height: 38, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("行动调整")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                Text("Action Adjustment")
                    .font(.subheadline)
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
    }
}

private struct GroupedTimeMenuRow: View {
    let title: String
    let systemImage: String
    let selectedTime: String
    let options: [String]
    let isLocked: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == selectedTime {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: DSTheme.Spacing.small) {
                Image(systemName: isLocked ? "lock.fill" : systemImage)
                    .foregroundStyle(isLocked ? DSTheme.Color.textSecondary : DSTheme.Color.primary)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textPrimary)

                Spacer(minLength: 0)

                Label(selectedTime, systemImage: "clock")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isLocked ? DSTheme.Color.textSecondary : Color(red: 0.05, green: 0.14, blue: 0.46))

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
            .padding(.horizontal, DSTheme.Spacing.medium)
            .frame(minHeight: 58)
            .background(isLocked ? DSTheme.Color.border.opacity(0.35) : .white)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DSTheme.Color.border, lineWidth: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

private struct GroupedAdjustmentSummary: View {
    let kind: GroupedAdjustmentKind
    let originalItems: [TodayActionItem]
    let changedItems: [TodayActionItem]

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Label("调整后的行动", systemImage: "calendar.badge.checkmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DSTheme.Color.primary)

                ForEach(Array(changedItems.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: DSTheme.Spacing.medium) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                            if let original = originalItems.first(where: { $0.id == item.id }) {
                                Text("原计划：\(original.startTimeText)  |  \(original.title)")
                                    .font(.caption)
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("开始时间")
                                .font(.caption)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                            Text(item.startTimeText)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(DSTheme.Color.warning)
                        }

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("行动内容")
                                .font(.caption)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                            Text(kind.contentText)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(DSTheme.Color.warning)
                        }
                    }
                    .padding(.vertical, 4)

                    if index < changedItems.count - 1 {
                        Divider()
                            .overlay(DSTheme.Color.border)
                    }
                }
            }
        }
    }
}

private struct AdjustmentConfirmBar: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DSTheme.Color.border)

            DSPrimaryButton("确认调整", isDisabled: isDisabled, action: action)
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, DSTheme.Spacing.small)
                .padding(.bottom, DSTheme.Spacing.small)
        }
        .background(.ultraThinMaterial)
    }
}

private enum MovementAdjustmentReason: String, CaseIterable, Identifiable, Hashable {
    case time = "时间安排变化"
    case duration = "想缩短运动时长"
    case energy = "精力变化"
    case scene = "场景变化"
    case otherExercise = "想尝试其他运动"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .time:
            "calendar.badge.clock"
        case .duration:
            "timer"
        case .energy:
            "battery.50percent"
        case .scene:
            "mappin.and.ellipse"
        case .otherExercise:
            "figure.run"
        }
    }
}

private enum MovementOption: String, CaseIterable, Identifiable, Hashable {
    case slowWalk = "慢走"
    case jogInPlace = "原地踏步"
    case calfRaise = "站姿提踵"
    case wallPushUp = "靠墙俯卧撑"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .slowWalk:
            "figure.walk"
        case .jogInPlace:
            "figure.highintensity.intervaltraining"
        case .calfRaise:
            "figure.strengthtraining.traditional"
        case .wallPushUp:
            "figure.core.training"
        }
    }

    var artworkAssetName: String? {
        switch self {
        case .slowWalk:
            "TodayCardWalk"
        case .jogInPlace:
            "TodayCardJogInPlace"
        case .calfRaise, .wallPushUp:
            nil
        }
    }

    var actionType: TodayActionType {
        switch self {
        case .slowWalk, .jogInPlace:
            .walk
        case .calfRaise, .wallPushUp:
            .custom
        }
    }
}

private struct MovementAdjustmentEditor: View {
    let originalItem: TodayActionItem
    let suggestion: ActionTrendSuggestion?
    let onBack: () -> Void
    let onSave: (TodayActionItem) -> Void

    @State private var selectedReasons: Set<MovementAdjustmentReason>
    @State private var selectedTime: String
    @State private var selectedDuration: Int
    @State private var selectedMovement: MovementOption
    @State private var customMovementName: String

    private let durationOptions = [10, 15, 20, 30]
    private let reasonColumns = [
        GridItem(.flexible(), spacing: DSTheme.Spacing.small),
        GridItem(.flexible(), spacing: DSTheme.Spacing.small)
    ]
    private let movementColumns = [
        GridItem(.flexible(), spacing: DSTheme.Spacing.small),
        GridItem(.flexible(), spacing: DSTheme.Spacing.small)
    ]

    init(
        item: TodayActionItem,
        suggestion: ActionTrendSuggestion?,
        onBack: @escaping () -> Void,
        onSave: @escaping (TodayActionItem) -> Void
    ) {
        self.originalItem = item
        self.suggestion = suggestion
        self.onBack = onBack
        self.onSave = onSave

        var reasons: Set<MovementAdjustmentReason> = []
        var timeText = item.startTimeText
        var duration = item.durationMinutes
        var movement = MovementOption.matching(item.title) ?? .slowWalk
        var customName = ""

        if let suggestion {
            switch suggestion.kind {
            case .reschedule:
                reasons.insert(.time)
            case .shorten:
                reasons.insert(.duration)
            case .switchExercise:
                if let proposedName = suggestion.proposedExerciseName,
                   let proposedMovement = MovementOption.matching(proposedName) {
                    reasons.insert(.energy)
                    movement = proposedMovement
                } else if let proposedName = suggestion.proposedExerciseName {
                    reasons.insert(.otherExercise)
                    customName = proposedName
                } else {
                    reasons.insert(.energy)
                }
            case .resolveConflict:
                reasons.insert(.time)
            case .keepPlan:
                break
            }

            if let proposedTime = suggestion.proposedStartTime,
               let proposedDate = AdjustmentClock.date(from: proposedTime, anchoredTo: item.scheduledStartAt) {
                reasons.insert(.time)
                timeText = TodayActionItem.timeFormatter.string(from: proposedDate)
            }

            if let proposedDuration = suggestion.proposedDurationMinutes {
                reasons.insert(.duration)
                duration = max(5, proposedDuration)
            }
        }

        self._selectedReasons = State(initialValue: reasons)
        self._selectedTime = State(initialValue: timeText)
        self._selectedDuration = State(initialValue: duration)
        self._selectedMovement = State(initialValue: movement)
        self._customMovementName = State(initialValue: customName)
    }

    private var isLocked: Bool {
        originalItem.status == .completed
    }

    private var showsMovementOptions: Bool {
        selectedReasons.contains(.energy) || selectedReasons.contains(.scene)
    }

    private var usesCustomMovement: Bool {
        selectedReasons.contains(.otherExercise)
    }

    private var trimmedCustomMovementName: String {
        customMovementName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var adjustedStartDate: Date {
        guard selectedReasons.contains(.time) else {
            return originalItem.scheduledStartAt
        }
        return AdjustmentClock.date(from: selectedTime, anchoredTo: originalItem.scheduledStartAt)
            ?? originalItem.scheduledStartAt
    }

    private var adjustedDuration: Int {
        selectedReasons.contains(.duration) ? selectedDuration : originalItem.durationMinutes
    }

    private var adjustedMovementName: String {
        if usesCustomMovement, !trimmedCustomMovementName.isEmpty {
            return trimmedCustomMovementName
        }
        if showsMovementOptions {
            return selectedMovement.rawValue
        }
        return originalItem.title
    }

    private var adjustedType: TodayActionType {
        if usesCustomMovement, !trimmedCustomMovementName.isEmpty {
            return .custom
        }
        if showsMovementOptions {
            return selectedMovement.actionType
        }
        return originalItem.type
    }

    private var adjustedCatalogExercise: LowBarrierExercise? {
        guard !usesCustomMovement,
              originalItem.exerciseId != nil,
              originalItem.exerciseScene != nil,
              originalItem.exerciseEnergy != nil else { return nil }

        if adjustedMovementName == originalItem.title,
           let originalExerciseID = originalItem.exerciseId,
           let originalExercise = LowBarrierExerciseCatalog.exercise(id: originalExerciseID) {
            return originalExercise
        }

        let catalogName = adjustedMovementName == MovementOption.calfRaise.rawValue
            ? "提踵"
            : adjustedMovementName
        let matches = LowBarrierExerciseCatalog.all.filter { $0.name == catalogName }

        if let originalSceneTitle = originalItem.exerciseScene,
           let originalScene = ExerciseScene(title: originalSceneTitle) {
            return matches.first(where: { $0.scene == originalScene })
        }

        return matches.first
    }

    private var customInputIsValid: Bool {
        !usesCustomMovement || !trimmedCustomMovementName.isEmpty
    }

    private var hasActualChange: Bool {
        !AdjustmentClock.isSameMinute(adjustedStartDate, originalItem.scheduledStartAt)
            || adjustedDuration != originalItem.durationMinutes
            || adjustedMovementName != originalItem.title
            || adjustedType != originalItem.type
    }

    private var canSave: Bool {
        !isLocked && !selectedReasons.isEmpty && customInputIsValid && hasActualChange
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                    AdjustmentDetailHeader(onBack: onBack)
                    originalPlanCard
                    reasonSelectionCard

                    if isLocked {
                        lockedNotice
                    } else {
                        if selectedReasons.contains(.time) {
                            startTimeCard
                        }

                        if selectedReasons.contains(.duration) {
                            durationCard
                        }

                        if showsMovementOptions {
                            movementOptionsCard
                        }

                        if usesCustomMovement {
                            customMovementCard
                        }
                    }

                    MovementAdjustmentSummary(
                        originalItem: originalItem,
                        startDate: adjustedStartDate,
                        movementName: adjustedMovementName,
                        durationMinutes: adjustedDuration
                    )
                }
                .padding(DSTheme.Spacing.large)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdjustmentConfirmBar(isDisabled: !canSave) {
                onSave(makeAdjustedItem())
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var originalPlanCard: some View {
        DSCard {
            HStack(spacing: DSTheme.Spacing.medium) {
                AdjustmentArtwork(
                    item: originalItem,
                    fallbackSystemImage: originalItem.type.systemImage
                )
                .frame(width: 126, height: 126)

                VStack(alignment: .leading, spacing: 9) {
                    Text(originalItem.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                    Text(isLocked ? "已完成" : "原计划")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isLocked ? DSTheme.Color.textSecondary : DSTheme.Color.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DSTheme.Color.primarySoft.opacity(0.75))
                        .clipShape(Capsule())

                    HStack(spacing: 10) {
                        Label(originalItem.startTimeText, systemImage: "clock")
                        Divider()
                            .frame(height: 18)
                        Label("\(originalItem.durationMinutes)分钟", systemImage: "timer")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var reasonSelectionCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("为什么需要调整？")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                    Text("可多选，相关设置会依次显示在下方。")
                        .font(.caption)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                LazyVGrid(columns: reasonColumns, alignment: .leading, spacing: DSTheme.Spacing.small) {
                    ForEach(MovementAdjustmentReason.allCases) { reason in
                        AdjustmentReasonButton(
                            reason: reason,
                            isSelected: selectedReasons.contains(reason),
                            isDisabled: isLocked
                        ) {
                            toggle(reason)
                        }
                    }
                }
            }
        }
    }

    private var lockedNotice: some View {
        DSCard {
            Label("这项行动已经完成，计划将保持不变。", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)
        }
    }

    private var startTimeCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Label("重新选择开始时间", systemImage: "clock.arrow.circlepath")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                GroupedTimeMenuRow(
                    title: "开始时间",
                    systemImage: "clock",
                    selectedTime: selectedTime,
                    options: AdjustmentClock.options(including: originalItem.scheduledStartAt),
                    isLocked: false
                ) { selectedTime = $0 }
            }
        }
    }

    private var durationCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Label("选择本次运动时长", systemImage: "timer")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                HStack(spacing: DSTheme.Spacing.small) {
                    ForEach(durationChoices, id: \.self) { minutes in
                        Button {
                            selectedDuration = minutes
                        } label: {
                            HStack(spacing: 5) {
                                Text("\(minutes)分钟")
                                if selectedDuration == minutes {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedDuration == minutes ? DSTheme.Color.primary : DSTheme.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(selectedDuration == minutes ? DSTheme.Color.primarySoft.opacity(0.7) : .white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(selectedDuration == minutes ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: 1.2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var movementOptionsCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedReasons.contains(.scene) ? "选择更适合当前场景的运动" : "选择其他低门槛运动")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                    Text("动作简单、无需器械，强度更容易控制。")
                        .font(.caption)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                LazyVGrid(columns: movementColumns, spacing: DSTheme.Spacing.small) {
                    ForEach(MovementOption.allCases) { movement in
                        MovementOptionButton(
                            movement: movement,
                            isSelected: selectedMovement == movement
                        ) {
                            selectedMovement = movement
                        }
                    }
                }
            }
        }
    }

    private var customMovementCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                Text("填写想尝试的运动")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                HStack {
                    TextField("例如：瑜伽", text: $customMovementName)
                        .foregroundStyle(DSTheme.Color.textPrimary)
                        .textInputAutocapitalization(.never)

                    if !customMovementName.isEmpty {
                        Button {
                            customMovementName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DSTheme.Spacing.medium)
                .frame(minHeight: 54)
                .background(.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(usesCustomMovement && trimmedCustomMovementName.isEmpty ? DSTheme.Color.warning : DSTheme.Color.border, lineWidth: 1.2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("系统会记录你的选择，并在今日行动中沿用相同的时间与时长格式。")
                    .font(.caption)
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
    }

    private var durationChoices: [Int] {
        Array(Set(durationOptions + [originalItem.durationMinutes, selectedDuration])).sorted()
    }

    private func toggle(_ reason: MovementAdjustmentReason) {
        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
        }
    }

    private func makeAdjustedItem() -> TodayActionItem {
        var updated = originalItem
        updated.scheduledStartAt = adjustedStartDate
        updated.durationMinutes = adjustedDuration
        updated.scheduledEndAt = Calendar.current.date(
            byAdding: .minute,
            value: adjustedDuration,
            to: adjustedStartDate
        ) ?? adjustedStartDate
        updated.title = adjustedMovementName
        updated.type = adjustedType

        if let catalogExercise = adjustedCatalogExercise {
            updated.type = .walk
            updated.exerciseId = catalogExercise.id
            updated.exerciseScene = catalogExercise.scene.rawValue
            updated.exerciseMovementAdvice = catalogExercise.movementAdvice
            updated.exerciseIntensityAdvice = catalogExercise.intensityAdvice
            updated.description = catalogExercise.movementAdvice
            updated.reason = "根据当前场景、精力和情景状态推荐的低门槛运动。"
        } else if originalItem.exerciseId != nil {
            // Keep adjusted catalog actions syncable without pretending that
            // an arbitrary custom activity has catalog-authored AI copy.
            updated.exerciseId = "custom-adjusted"
            updated.exerciseMovementAdvice = adjustedType.description(durationMinutes: adjustedDuration)
            updated.exerciseIntensityAdvice = "保持自然呼吸和舒适节奏；如有明显不适，请停止并休息。"
            updated.type = .walk
            updated.description = adjustedType.description(durationMinutes: adjustedDuration)
            updated.reason = adjustedType.reason
        } else {
            updated.exerciseId = nil
            updated.exerciseScene = nil
            updated.exerciseEnergy = nil
            updated.exerciseContexts = []
            updated.exerciseMovementAdvice = nil
            updated.exerciseIntensityAdvice = nil
            updated.description = adjustedType.description(durationMinutes: adjustedDuration)
            updated.reason = adjustedType.reason
        }

        updated.status = .pending
        updated.displayStatus = .pending
        updated.completedAt = nil
        return updated
    }
}

private struct AdjustmentReasonButton: View {
    let reason: MovementAdjustmentReason
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: reason.systemImage)
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : DSTheme.Color.textSecondary)
                    .frame(width: 22)

                Text(reason.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : DSTheme.Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : DSTheme.Color.border)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(isSelected ? DSTheme.Color.primarySoft.opacity(0.55) : .white)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct MovementOptionButton: View {
    let movement: MovementOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let assetName = movement.artworkAssetName {
                            Image(assetName)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: movement.systemImage)
                                .font(.system(size: 37, weight: .medium))
                                .foregroundStyle(DSTheme.Color.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(DSTheme.Color.primarySoft.opacity(0.55))
                        }
                    }
                    .frame(height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(DSTheme.Color.primary)
                            .background(Circle().fill(.white))
                            .offset(x: 4, y: 4)
                    }
                }

                Text(movement.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : DSTheme.Color.textPrimary)
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(isSelected ? DSTheme.Color.primarySoft.opacity(0.45) : .white)
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MovementAdjustmentSummary: View {
    let originalItem: TodayActionItem
    let startDate: Date
    let movementName: String
    let durationMinutes: Int

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Label("调整后的行动", systemImage: "calendar.badge.checkmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DSTheme.Color.primary)

                HStack(alignment: .top, spacing: 0) {
                    summaryColumn(
                        title: "开始时间",
                        value: TodayActionItem.timeFormatter.string(from: startDate)
                    )

                    Divider()
                        .frame(height: 52)

                    summaryColumn(title: "运动种类", value: movementName)

                    Divider()
                        .frame(height: 52)

                    summaryColumn(title: "运动时长", value: "\(durationMinutes)分钟")
                }

                Text("原计划：\(originalItem.startTimeText)  |  \(originalItem.title)  |  \(originalItem.durationMinutes)分钟")
                    .font(.caption)
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryColumn(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(DSTheme.Color.warning)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum AdjustmentClock {
    static func options(including date: Date) -> [String] {
        let halfHours = (0..<48).map { index in
            String(format: "%02d:%02d", index / 2, index.isMultiple(of: 2) ? 0 : 30)
        }
        return Array(Set(halfHours + [TodayActionItem.timeFormatter.string(from: date)]))
            .sorted { minutes(from: $0) < minutes(from: $1) }
    }

    static func date(from value: String, anchoredTo anchor: Date) -> Date? {
        if let hourMinute = hourMinute(from: value) {
            return Calendar.current.date(
                bySettingHour: hourMinute.hour,
                minute: hourMinute.minute,
                second: 0,
                of: anchor
            )
        }

        for formatter in isoFormatters {
            if let parsed = formatter.date(from: value) {
                let components = Calendar.current.dateComponents([.hour, .minute], from: parsed)
                guard let hour = components.hour, let minute = components.minute else {
                    continue
                }
                return Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: anchor
                )
            }
        }

        return nil
    }

    static func isSameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.compare(lhs, to: rhs, toGranularity: .minute) == .orderedSame
    }

    private static func hourMinute(from value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":")
        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0..<24).contains(hour),
            (0..<60).contains(minute)
        else {
            return nil
        }
        return (hour, minute)
    }

    private static func minutes(from value: String) -> Int {
        guard let result = hourMinute(from: value) else {
            return Int.max
        }
        return result.hour * 60 + result.minute
    }

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return [fractional, standard]
    }()
}

private extension MovementOption {
    static func matching(_ value: String) -> MovementOption? {
        allCases.first { option in
            value == option.rawValue || value.contains(option.rawValue)
        }
    }
}
