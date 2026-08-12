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
    private let statusBarClearance: CGFloat = 54

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
        savedReadings.first { Calendar.current.isDateInToday($0.measuredAt) }
    }

    private var entries: [ActionAdjustmentEntry] {
        ActionAdjustmentEntry.makeEntries(from: adjustableItems)
    }

    private var adjustableItems: [TodayActionItem] {
        items.filter(\.isExerciseAction)
    }

    private var suggestionRefreshKey: String {
        adjustableItems
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
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.99, blue: 1.0),
                        Color(red: 0.91, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        todayStatusCard
                        trendSuggestionsCard
                        actionListCard
                    }
                    .padding(.horizontal, DSTheme.Spacing.medium)
                    .padding(.top, statusBarClearance)
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
                await viewModel.refresh(items: adjustableItems, userId: userId)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            AdjustmentPageTitle()
        }
    }

    private var todayStatusCard: some View {
        let state = ActionGenerationBloodPressureState(reading: latestReading)
        return DSCard(
            padding: DSTheme.Spacing.small,
            backgroundColor: Color(red: 1.0, green: 239.0 / 255.0, blue: 199.0 / 255.0)
        ) {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                HStack(spacing: 8) {
                    Label("今日最新血压", systemImage: "heart.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(DSTheme.Color.textSecondary)
                    Spacer()
                    Label(state.title, systemImage: state.systemImage)
                        .font(.caption2.weight(.bold)).foregroundStyle(state.tint)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(state.tint.opacity(0.12)).clipShape(Capsule())
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(latestReading.map { "\($0.systolic) / \($0.diastolic)" } ?? "-- / --")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.45))
                    Text("mmHg").font(.caption.weight(.bold)).foregroundStyle(DSTheme.Color.textSecondary)
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.87, green: 0.92, blue: 0.99), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.18, green: 0.39, blue: 0.82).opacity(0.08), radius: 14, x: 0, y: 7)
    }

    private var trendSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DSTheme.Color.primary)

                Text("趋势调整")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                Spacer(minLength: 8)

                Text(viewModel.evidenceDays > 1 ? "基于近\(viewModel.evidenceDays)天记录为你提供优化建议" : "基于近期趋势为你提供优化建议")
                    .font(.caption2)
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            if viewModel.isLoading && viewModel.suggestions.isEmpty {
                TrendSuggestionRow(
                    systemImage: "clock",
                    message: "正在分析当前行动安排..."
                )
            } else if viewModel.suggestions.isEmpty {
                TrendSuggestionRow(
                    systemImage: "checkmark.circle.fill",
                    message: viewModel.dataNote ?? "当前没有需要调整的行动。"
                )
            } else {
                ForEach(viewModel.suggestions) { suggestion in
                    Button {
                        guard let target = target(for: suggestion) else {
                            return
                        }
                        path.append(ActionAdjustmentRoute(target: target, suggestion: suggestion))
                    } label: {
                        TrendSuggestionRow(
                            systemImage: suggestion.kind.systemImage,
                            message: suggestion.message,
                            showsChevron: suggestion.targetActionId != nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(suggestion.targetActionId == nil)
                }
            }

            Label("建议将根据你的数据持续优化。", systemImage: "info.circle.fill")
                .font(.caption2)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .padding(.top, 2)
        }
        .padding(14)
        .actionAdjustmentCardStyle()
    }

    private func target(for suggestion: ActionTrendSuggestion) -> ActionAdjustmentTarget? {
        guard
            let targetID = suggestion.targetActionId,
            let item = adjustableItems.first(where: { $0.id == targetID }),
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
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    let entry: ActionAdjustmentEntry
    let onAdjust: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularLayout
            compactLayout
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var regularLayout: some View {
        HStack(spacing: 10) {
            artwork(size: 72)

            informationBlock
                .frame(minWidth: 104, maxWidth: .infinity, alignment: .leading)

            actionControls
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
        }
    }

    private var compactLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            artwork(size: 64)

            VStack(alignment: .leading, spacing: 9) {
                informationBlock

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    actionControls
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private func artwork(size: CGFloat) -> some View {
        AdjustmentArtwork(
            assetName: entry.artworkAssetName(for: exercisePresentationSex),
            fallbackSystemImage: entry.systemImage
        )
            .frame(width: size, height: size)
    }

    private var informationBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.52, blue: 0.82))

                Text(entry.scheduleText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionControls: some View {
        if entry.hasAdjustableItems {
            HStack(spacing: 8) {
                Text("可调整")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DSTheme.Color.success)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.89, green: 0.98, blue: 0.91))
                    .clipShape(Capsule())

                Button(action: onAdjust) {
                    HStack(spacing: 5) {
                        Text("调整")
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay {
                        Capsule()
                            .stroke(DSTheme.Color.primary.opacity(0.65), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("已完成")
                .font(.caption2.weight(.bold))
                .foregroundStyle(DSTheme.Color.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(DSTheme.Color.border.opacity(0.55))
                .clipShape(Capsule())
        }
    }
}

private struct AdjustmentArtwork: View {
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    private let explicitAssetName: String?
    private let item: TodayActionItem?
    let fallbackSystemImage: String

    init(assetName: String, fallbackSystemImage: String) {
        self.explicitAssetName = assetName
        self.item = nil
        self.fallbackSystemImage = fallbackSystemImage
    }

    init(item: TodayActionItem?, fallbackSystemImage: String) {
        self.explicitAssetName = nil
        self.item = item
        self.fallbackSystemImage = fallbackSystemImage
    }

    var body: some View {
        Group {
            Image(resolvedAssetName)
                .resizable()
                .scaledToFit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSTheme.Color.primarySoft.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.93, blue: 1.0), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var resolvedAssetName: String {
        explicitAssetName ?? Self.assetName(
            for: item,
            fallbackSystemImage: fallbackSystemImage,
            presentationSex: exercisePresentationSex
        )
    }

    private static func assetName(
        for item: TodayActionItem?,
        fallbackSystemImage: String,
        presentationSex: ExercisePresentationSex
    ) -> String {
        guard let item else {
            return "ActionAdjustWalk"
        }

        if let assetName = item.timelineArtworkAssetName(for: presentationSex) {
            return assetName
        }

        if item.type == .bpRecheck || item.title.contains("血压") {
            return "ActionAdjustBloodPressure"
        }

        if item.type == .diet || item.title.contains("餐") || item.title.contains("饮食") {
            return "ActionAdjustDiet"
        }

        if item.type == .walk || item.title.contains("步") || item.title.contains("走") {
            return "ActionAdjustWalk"
        }

        return item.timelineArtworkAssetName(for: presentationSex) ?? "ActionAdjustWalk"
    }
}

private struct TrendSuggestionRow: View {
    let systemImage: String
    let message: String
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DSTheme.Color.primary)
                .frame(width: 42, height: 42)
                .background(DSTheme.Color.primarySoft.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.98, green: 0.995, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.93, blue: 1.0), lineWidth: 1)
        }
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

    func artworkAssetName(for presentationSex: ExercisePresentationSex) -> String {
        switch target {
        case .bloodPressure:
            return "ActionAdjustBloodPressure"
        case .diet:
            return "ActionAdjustDiet"
        case .single:
            guard let item = items.first else {
                return "ActionAdjustWalk"
            }

            if let assetName = item.timelineArtworkAssetName(for: presentationSex) {
                return assetName
            }

            if item.type == .walk || item.title.contains("步") || item.title.contains("走") {
                return "ActionAdjustWalk"
            }

            if item.type == .bpRecheck {
                return "ActionAdjustBloodPressure"
            }

            if item.type == .diet {
                return "ActionAdjustDiet"
            }

            return item.timelineArtworkAssetName(for: presentationSex) ?? "ActionAdjustWalk"
        }
    }

    static func makeEntries(from items: [TodayActionItem]) -> [ActionAdjustmentEntry] {
        let sortedItems = items.filter(\.isExerciseAction).sortedByStartTime()
        var entries: [ActionAdjustmentEntry] = []

        for item in sortedItems {
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

private extension View {
    func actionAdjustmentCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(red: 0.87, green: 0.92, blue: 0.99), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.18, green: 0.39, blue: 0.82).opacity(0.08), radius: 14, x: 0, y: 7)
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
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                    .frame(width: 38, height: 38, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("行动调整")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                    Text("Action Adjustment")
                        .font(.subheadline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                Spacer()
            }
        }
    }
}

private struct IconText: View {
    let assetName: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(Color(red: 0.36, green: 0.52, blue: 0.82))

            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
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
            DSPrimaryButton("确认调整", isDisabled: isDisabled, action: action)
                .padding(.horizontal, DSTheme.Spacing.medium)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(.white)
        .shadow(color: Color(red: 0.18, green: 0.39, blue: 0.82).opacity(0.08), radius: 14, x: 0, y: -6)
    }
}

private enum MovementAdjustmentReason: String, CaseIterable, Identifiable, Hashable {
    case time = "时间变化"
    case energy = "精力变化"
    case scene = "场景变化"
    case otherExercise = "想尝试其他运动"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .time:
            "calendar.badge.clock"
        case .energy:
            "battery.50percent"
        case .scene:
            "mappin.and.ellipse"
        case .otherExercise:
            "figure.run"
        }
    }

    var assetName: String {
        switch self {
        case .time:
            "ActionAdjustReasonTime"
        case .energy:
            "ActionAdjustReasonEnergy"
        case .scene:
            "ActionAdjustReasonScene"
        case .otherExercise:
            "ActionAdjustReasonExercise"
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

    func artworkAssetName(for presentationSex: ExercisePresentationSex) -> String? {
        let femaleAssetName: String?
        switch self {
        case .slowWalk:
            femaleAssetName = "ExerciseSlowWalk"
        case .jogInPlace:
            femaleAssetName = "ExerciseMarchInPlace"
        case .calfRaise:
            femaleAssetName = "ExerciseCalfRaise"
        case .wallPushUp:
            femaleAssetName = "ExerciseWallPushUp"
        }

        guard let femaleAssetName else { return nil }
        return presentationSex == .male ? "\(femaleAssetName)Male" : femaleAssetName
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
    @State private var selectedEndTime: String
    @State private var selectedMovement: MovementOption
    @State private var customMovementName: String

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
        var endTimeText = item.endTimeText
        var movement = MovementOption.matching(item.title) ?? .slowWalk
        var customName = ""

        if let suggestion {
            switch suggestion.kind {
            case .reschedule:
                reasons.insert(.time)
            case .shorten:
                reasons.insert(.time)
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
                endTimeText = ExerciseTimeRange.endTime(
                    startTime: timeText,
                    durationMinutes: item.durationMinutes
                )
            }

            if let proposedDuration = suggestion.proposedDurationMinutes {
                reasons.insert(.time)
                endTimeText = ExerciseTimeRange.endTime(
                    startTime: timeText,
                    durationMinutes: max(5, proposedDuration)
                )
            }
        }

        let usesDefaultEnergyAdjustment = reasons.isEmpty
        if usesDefaultEnergyAdjustment {
            movement = .slowWalk
        }

        self._selectedReasons = State(initialValue: usesDefaultEnergyAdjustment ? [.energy] : reasons)
        self._selectedTime = State(initialValue: timeText)
        self._selectedEndTime = State(initialValue: endTimeText)
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

    private func isReasonDisabled(_ reason: MovementAdjustmentReason) -> Bool {
        isLocked || (selectedReasons.contains(.otherExercise) && (reason == .energy || reason == .scene))
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
        guard selectedReasons.contains(.time) else {
            return originalItem.durationMinutes
        }
        return ExerciseTimeRange.durationMinutes(
            from: TodayActionItem.timeFormatter.string(from: adjustedStartDate),
            to: selectedEndTime
        )
    }

    private var adjustedEndDate: Date {
        Calendar.current.date(
            byAdding: .minute,
            value: adjustedDuration,
            to: adjustedStartDate
        ) ?? adjustedStartDate
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
        guard !usesCustomMovement else { return nil }

        // When the user only changes the time, keep the original catalog
        // exercise. A free-text custom exercise must remain custom.
        guard showsMovementOptions else {
            guard let originalExerciseID = originalItem.exerciseId else { return nil }
            return LowBarrierExerciseCatalog.exercise(id: originalExerciseID)
        }

        if adjustedMovementName == originalItem.title,
           let originalExerciseID = originalItem.exerciseId,
           let originalExercise = LowBarrierExerciseCatalog.exercise(id: originalExerciseID) {
            return originalExercise
        }

        return LowBarrierExerciseCatalog.adjustmentExercise(
            named: adjustedMovementName,
            preferredSceneTitle: originalItem.exerciseScene
        )
    }

    private var customInputIsValid: Bool {
        !usesCustomMovement || !trimmedCustomMovementName.isEmpty
    }

    private var canSave: Bool {
        !isLocked && !selectedReasons.isEmpty && customInputIsValid
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.99, blue: 1.0),
                    Color(red: 0.91, green: 0.96, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    AdjustmentDetailHeader(onBack: onBack)
                    originalPlanCard
                    reasonSelectionCard

                    if isLocked {
                        lockedNotice
                    } else {
                        if selectedReasons.contains(.time) {
                            timeRangeCard
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
                        endDate: adjustedEndDate,
                        movementName: adjustedMovementName
                    )
                }
                .padding(.horizontal, DSTheme.Spacing.medium)
                .padding(.top, 10)
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
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)

                AdjustmentArtwork(
                    item: originalItem,
                    fallbackSystemImage: originalItem.type.systemImage
                )
                .padding(6)
            }
            .frame(width: 132, height: 112)

            VStack(alignment: .leading, spacing: 10) {
                Text(isLocked ? "已完成" : "原计划")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isLocked ? DSTheme.Color.textSecondary : DSTheme.Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DSTheme.Color.primarySoft.opacity(0.75))
                    .clipShape(Capsule())

                Text(originalItem.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                IconText(assetName: "ActionAdjustClock", text: originalItem.timeRangeText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actionAdjustmentCardStyle()
    }

    private var reasonSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("为什么需要调整？")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                Text("可多选，系统会根据你的选择生成调整方案。")
                    .font(.caption)
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }

            LazyVGrid(columns: reasonColumns, alignment: .leading, spacing: DSTheme.Spacing.small) {
                ForEach(MovementAdjustmentReason.allCases) { reason in
                    AdjustmentReasonButton(
                        reason: reason,
                        isSelected: selectedReasons.contains(reason),
                        isDisabled: isReasonDisabled(reason)
                    ) {
                        toggle(reason)
                    }
                }
            }
        }
        .padding(12)
        .actionAdjustmentCardStyle()
    }

    private var lockedNotice: some View {
        DSCard {
            Label("这项行动已经完成，计划将保持不变。", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)
        }
    }

    private var timeRangeCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Label("重新选择运动时间", systemImage: "clock.arrow.circlepath")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                ExerciseTimeRangePicker(
                    startTime: $selectedTime,
                    endTime: $selectedEndTime
                )
            }
        }
    }

    private var movementOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("选择其他低门槛运动")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                Text("动作简单、无需器械，强度更容易控制。")
                    .font(.caption)
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }

            LazyVGrid(columns: movementColumns, spacing: 10) {
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
        .padding(12)
        .actionAdjustmentCardStyle()
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

    private func toggle(_ reason: MovementAdjustmentReason) {
        guard !isReasonDisabled(reason) else {
            return
        }

        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
            if reason == .otherExercise {
                selectedReasons.remove(.energy)
                selectedReasons.remove(.scene)
            }
        }
    }

    private func makeAdjustedItem() -> TodayActionItem {
        var updated = originalItem
        updated.scheduledStartAt = adjustedStartDate
        updated.durationMinutes = adjustedDuration
        updated.scheduledEndAt = adjustedEndDate
        updated.title = adjustedMovementName
        updated.type = adjustedType

        if let catalogExercise = adjustedCatalogExercise {
            updated.type = .walk
            updated.exerciseId = catalogExercise.id
            updated.exerciseScene = catalogExercise.scene.rawValue
            updated.exerciseEnergy = originalItem.exerciseEnergy ?? catalogExercise.energyTier.title
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
            updated.type = usesCustomMovement ? .custom : adjustedType
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
        updated.actualStartedAt = nil
        updated.timerLastResumedAt = nil
        updated.timerAccumulatedSeconds = 0
        updated.actualEndedAt = nil
        updated.actualDurationSeconds = nil
        updated.completionMode = nil
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
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 7) {
                    Image(reason.assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(isSelected ? DSTheme.Color.primary : Color(red: 0.47, green: 0.52, blue: 0.66))

                    Text(reason.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? DSTheme.Color.primary : Color(red: 0.05, green: 0.14, blue: 0.46))
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .background(Circle().fill(.white))
                        .offset(x: 4, y: 4)
                }
            }
            .background(isSelected ? Color(red: 0.93, green: 0.97, blue: 1.0) : .white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    MovementOptionArtwork(movement: movement)
                        .frame(height: 86)
                        .frame(maxWidth: .infinity)

                    Text(movement.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? DSTheme.Color.primary : Color(red: 0.05, green: 0.14, blue: 0.46))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 3)
                        .padding(.bottom, 8)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .background(Circle().fill(.white))
                        .offset(x: 5, y: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 122)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MovementOptionArtwork: View {
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    let movement: MovementOption

    var body: some View {
        ZStack {
            Color.white

            if let assetName = movement.artworkAssetName(for: exercisePresentationSex) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, movement == .jogInPlace ? 34 : 14)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            } else {
                Image(systemName: movement.systemImage)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 64, height: 64)
                    .background(DSTheme.Color.primarySoft.opacity(0.65))
                    .clipShape(Circle())
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MovementAdjustmentSummary: View {
    let originalItem: TodayActionItem
    let startDate: Date
    let endDate: Date
    let movementName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("调整后的行动")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DSTheme.Color.primary)

            HStack(alignment: .top, spacing: 0) {
                summaryColumn(
                    title: "开始时间",
                    value: TodayActionItem.timeFormatter.string(from: startDate)
                )

                Divider()
                    .frame(height: 44)

                summaryColumn(
                    title: "结束时间",
                    value: TodayActionItem.timeFormatter.string(from: endDate)
                )

                Divider()
                    .frame(height: 44)

                summaryColumn(title: "运动种类", value: movementName)
            }

            Text("原计划：\(originalItem.timeRangeText)  |  \(originalItem.title)")
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.96, blue: 1.0),
                    Color(red: 0.98, green: 0.995, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.87, green: 0.92, blue: 0.99), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.18, green: 0.39, blue: 0.82).opacity(0.08), radius: 14, x: 0, y: 7)
    }

    private func summaryColumn(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(red: 0.29, green: 0.39, blue: 0.58))

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
