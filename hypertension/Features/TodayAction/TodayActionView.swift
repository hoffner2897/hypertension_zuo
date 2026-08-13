import SwiftUI
import SwiftData

struct TodayActionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    @Binding var items: [TodayActionItem]
    let userId: String
    let onOpenBloodPressure: (Date?) -> Void

    @State private var path: [TodayActionRoute] = []
    @State private var activeMealItem: TodayActionItem?
    @State private var activeExerciseItem: TodayActionItem?
    @State private var isShowingAccountSettings = false
    @State private var mealRecords: [MealKind: MealRecord] = [:]
    @State private var headerDisplayName = "我的"
    @State private var treeCompletionRate = 0.0
    @Query private var savedReadings: [BloodPressureReading]
    private let mealRecordService = MealRecordService()
    private let exerciseActionService = ExerciseActionService()
    private let researchActionSyncService = ResearchActionSyncService()
    private let profileService = ProfileService()
    private let statusBarClearance: CGFloat = 54

    init(
        items: Binding<[TodayActionItem]>,
        userId: String,
        onOpenBloodPressure: @escaping (Date?) -> Void = { _ in }
    ) {
        self._items = items
        self.userId = userId
        self.onOpenBloodPressure = onOpenBloodPressure
        self._savedReadings = Query(
            filter: #Predicate<BloodPressureReading> { reading in
                reading.userId == userId
            },
            sort: \BloodPressureReading.measuredAt,
            order: .reverse
        )
    }

    private var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    private var remainingCount: Int {
        max(items.count - completedCount, 0)
    }

    private var currentCompletionRate: Double {
        guard !items.isEmpty else {
            return 0
        }

        return Double(completedCount) / Double(items.count)
    }

    private var readingRefreshKey: String {
        savedReadings
            .filter { Calendar.current.isDateInToday($0.measuredAt) }
            .map { "\($0.id.uuidString)-\($0.systolic)-\($0.diastolic)-\($0.measuredAt.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                TreeStageBackground(completionRate: treeCompletionRate)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DSTheme.Spacing.medium) {
                        header
                        summaryCards
                        timelineScene
                    }
                    .padding(.horizontal, DSTheme.Spacing.medium)
                    .padding(.top, statusBarClearance)
                    .padding(.bottom, 170)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: TodayActionRoute.self) { route in
                switch route {
                case .detail(let id):
                    if let item = item(with: id) {
                        TodayActionDetailView(
                            item: item,
                            effectiveStatus: item.effectiveStatus(now: Date()),
                            onComplete: { updateStatus(.completed, for: id) }
                        )
                    }
                }
            }
            .sheet(item: $activeMealItem) { item in
                MealRecordSheet(
                    item: item,
                    userId: userId,
                    existingRecord: mealRecord(for: item),
                    onSaved: { record in
                        mealRecords[record.mealType] = record
                        applyMealRecord(record)
                    },
                    onClose: {
                        activeMealItem = nil
                    }
                )
            }
            .sheet(item: $activeExerciseItem) { item in
                ExerciseRecordSheet(
                    item: item,
                    onUpdate: { update in
                        applyExerciseTimerUpdate(update, to: item.id)
                    },
                    onDelete: {
                        deleteExerciseAction(item.id)
                        activeExerciseItem = nil
                    },
                    onClose: {
                        activeExerciseItem = nil
                    }
                )
            }
            .sheet(isPresented: $isShowingAccountSettings) {
                AccountSettingsView()
            }
            .task(id: userId) {
                items = ActionHistoryStore.restoreToday(items, userId: userId)
                applyTodayBloodPressureReadings()
                ActionHistoryStore.saveToday(items, userId: userId)
                await loadMealRecords()
                await reconcileExerciseActions()
                await syncResearchSnapshot(items)
                await loadHeaderProfile()
                treeCompletionRate = TreeProgressStore.record(currentCompletionRate, userId: userId)
            }
            .onChange(of: isShowingAccountSettings) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    Task { await loadHeaderProfile() }
                }
            }
            .onChange(of: readingRefreshKey) { _, _ in
                applyTodayBloodPressureReadings()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await reconcileExerciseActions()
                    await syncResearchSnapshot(items)
                }
            }
            .onChange(of: items) { _, updatedItems in
                ActionHistoryStore.saveToday(updatedItems, userId: userId)
                Task {
                    await syncExerciseActions(updatedItems)
                    await syncResearchSnapshot(updatedItems)
                }
                treeCompletionRate = TreeProgressStore.record(currentCompletionRate, userId: userId)
            }
        }
    }

    /// Research sync is deliberately best-effort: the local tree remains the source for UI/offline use,
    /// and the next item change or foreground activation retries the complete current-day snapshot.
    private func syncResearchSnapshot(_ currentItems: [TodayActionItem]) async {
        try? await researchActionSyncService.sync(items: currentItems)
    }

    private var header: some View {
        HStack(alignment: .top) {
            ActionPageTitle(title: "今日行动", subtitle: "Today's Action")

            Spacer()

            Button {
                isShowingAccountSettings = true
            } label: {
                VStack(spacing: 4) {
                    Image(exercisePresentationSex.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

                    Text(headerDisplayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开账号与健康数据")
        }
    }

    private var summaryCards: some View {
        HStack(spacing: DSTheme.Spacing.small) {
            TodaySummaryCard(
                imageName: "TodaySummaryCompleted",
                title: "已完成",
                value: "\(completedCount)",
                suffix: "项"
            )

            TodaySummaryCard(
                imageName: "TodaySummaryRemaining",
                title: "还剩",
                value: "\(remainingCount)",
                suffix: "项"
            )
        }
    }

    private var timelineScene: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let now = context.date
            let displayItems = items.map { item in
                var copy = item
                copy.displayStatus = item.effectiveStatus(now: now)
                return copy
            }
            let layout = TimelinePositioner.layout(items: displayItems, now: now)

            TodayTreeTimelineView(
                items: displayItems,
                now: now,
                layout: layout,
                onSelect: { id in
                    guard let item = item(with: id) else { return }
                    if item.type == .diet {
                        activeMealItem = item
                    } else if item.type == .bpRecheck {
                        onOpenBloodPressure(item.scheduledStartAt)
                    } else if item.isExerciseAction {
                        activeExerciseItem = item
                    } else {
                        path.append(.detail(id))
                    }
                }
            )
            .frame(height: layout.contentHeight)
        }
    }

    private func item(with id: UUID) -> TodayActionItem? {
        items.first { $0.id == id }
    }

    private func updateStatus(_ status: TodayActionStatus, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].status = status
        items[index].clientUpdatedAt = Date()
        if status == .completed {
            items[index].completedAt = Date()
        }
        path.removeAll()
    }

    private func replaceItem(_ item: TodayActionItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        var updatedItem = item
        updatedItem.clientUpdatedAt = Date()
        items[index] = updatedItem
    }

    private func applyExerciseTimerUpdate(_ update: ExerciseTimerUpdate, to id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = update.status
        items[index].displayStatus = update.status
        items[index].actualStartedAt = update.actualStartedAt
        items[index].timerLastResumedAt = update.timerLastResumedAt
        items[index].timerAccumulatedSeconds = update.timerAccumulatedSeconds
        items[index].actualEndedAt = update.actualEndedAt
        items[index].actualDurationSeconds = update.actualDurationSeconds
        items[index].completionMode = update.completionMode
        items[index].completedAt = update.status == .completed ? update.actualEndedAt : nil
        items[index].clientUpdatedAt = Date()
        activeExerciseItem = items[index]
    }

    private func deleteExerciseAction(_ id: UUID) {
        guard let item = item(with: id), item.isExerciseAction else { return }
        ExerciseTimerNotificationService.cancel(for: id)
        items.removeAll { $0.id == id }
        ActionHistoryStore.saveToday(items, userId: userId)
        Task {
            try? await exerciseActionService.delete(id: id)
        }
    }

    private func mealRecord(for item: TodayActionItem) -> MealRecord? {
        guard let mealKind = MealKind(actionTitle: item.title) else { return nil }
        return mealRecords[mealKind]
    }

    private func loadMealRecords() async {
        guard !userId.isEmpty else { return }
        do {
            let records = try await mealRecordService.records()
            mealRecords = Dictionary(uniqueKeysWithValues: records.map { ($0.mealType, $0) })
            for record in records {
                applyMealRecord(record)
            }
        } catch {
            // Keep today's actions usable offline; records will load on the next refresh.
        }
    }

    private func loadHeaderProfile() async {
        guard !userId.isEmpty else { return }
        guard let response = try? await profileService.fetchProfile(),
              let profile = response.profile else { return }
        let trimmedName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            headerDisplayName = trimmedName
        }
    }

    private func reconcileExerciseActions() async {
        guard !userId.isEmpty else { return }

        do {
            let remoteActions = try await exerciseActionService.actions()
            var mergedItems = items

            for (remoteIndex, remoteAction) in remoteActions.enumerated() {
                guard let remoteItem = TodayActionItem(
                    remoteExerciseAction: remoteAction,
                    sortOrder: mergedItems.count + remoteIndex
                ) else { continue }

                if let localIndex = mergedItems.firstIndex(where: { $0.id == remoteItem.id }) {
                    if remoteItem.clientUpdatedAt >= mergedItems[localIndex].clientUpdatedAt {
                        mergedItems[localIndex] = remoteItem
                    }
                } else {
                    mergedItems.append(remoteItem)
                }
            }

            mergedItems.sort { $0.scheduledStartAt < $1.scheduledStartAt }
            for index in mergedItems.indices {
                mergedItems[index].sortOrder = index
            }
            items = mergedItems
            ActionHistoryStore.saveToday(mergedItems, userId: userId)
            await syncExerciseActions(mergedItems)
        } catch {
            // Offline-first: keep the local copy and retry automatically after
            // the next action change, foreground activation, or app launch.
            await syncExerciseActions(items)
        }
    }

    private func syncExerciseActions(_ actionItems: [TodayActionItem]) async {
        guard !userId.isEmpty else { return }

        for item in actionItems where item.exerciseId != nil {
            guard let input = ExerciseActionSyncInput(item: item) else { continue }
            do {
                let result = try await exerciseActionService.upsert(id: item.id, input: input)
                guard !result.applied,
                      let remoteItem = TodayActionItem(remoteExerciseAction: result.action),
                      let localIndex = items.firstIndex(where: { $0.id == remoteItem.id }),
                      remoteItem.clientUpdatedAt > items[localIndex].clientUpdatedAt else {
                    continue
                }

                items[localIndex] = remoteItem
                ActionHistoryStore.saveToday(items, userId: userId)
            } catch {
                // The local observation remains the source for the next retry.
            }
        }
    }

    private func applyMealRecord(_ record: MealRecord) {
        guard let index = items.firstIndex(where: {
            $0.type == .diet && MealKind(actionTitle: $0.title) == record.mealType
        }) else { return }

        items[index].status = .completed
        items[index].displayStatus = .completed
        items[index].completedAt = ISO8601DateFormatter().date(from: record.recordedAt) ?? Date()
        items[index].adviceText = record.cardSummary
    }

    private func applyTodayBloodPressureReadings() {
        let todayReadings = savedReadings
            .filter { Calendar.current.isDateInToday($0.measuredAt) }
            .sorted { $0.measuredAt < $1.measuredAt }

        let morningReading = todayReadings.first {
            Calendar.current.component(.hour, from: $0.measuredAt) < 12
        }
        let eveningReading = todayReadings.last {
            Calendar.current.component(.hour, from: $0.measuredAt) >= 12
        }

        for index in items.indices where items[index].type == .bpRecheck {
            let reading = items[index].title.contains("早晨") ? morningReading : eveningReading
            if let reading {
                items[index].status = .completed
                items[index].displayStatus = .completed
                items[index].completedAt = reading.measuredAt
                items[index].bloodPressureText = "\(reading.systolic)/\(reading.diastolic)"
            } else {
                if items[index].status == .completed {
                    items[index].status = .pending
                    items[index].displayStatus = .pending
                    items[index].completedAt = nil
                }
                items[index].bloodPressureText = nil
            }
        }
    }
}

struct ActionGenerateDemoView: View {
    let userId: String
    let onGenerateAction: (TodayActionItem) -> Void
    let onSafetyBlock: () -> Void
    @Query private var savedReadings: [BloodPressureReading]
    @State private var activeSheet: ActionGenerationSheet?
    @State private var scene = "公共室内"
    @State private var energy = "精力一般"
    @State private var contexts: Set<String> = ["饭后"]
    @State private var hasDiscomfort = false
    @State private var currentExerciseId = "public-indoor-slow-walk"
    @State private var currentTime = "15:30"
    @State private var currentEndTime = "15:45"
    @State private var customMovementName = ""
    @State private var preferenceStartTime = "18:30"
    @State private var preferenceEndTime = "19:30"

    init(
        userId: String,
        onGenerateAction: @escaping (TodayActionItem) -> Void,
        onSafetyBlock: @escaping () -> Void = {}
    ) {
        self.userId = userId
        self.onGenerateAction = onGenerateAction
        self.onSafetyBlock = onSafetyBlock
        self._savedReadings = Query(
            filter: #Predicate<BloodPressureReading> { reading in
                reading.userId == userId
            },
            sort: \BloodPressureReading.measuredAt,
            order: .reverse
        )
    }

    private var latestTodayReading: BloodPressureReading? {
        savedReadings.first { Calendar.current.isDateInToday($0.measuredAt) }
    }

    private var bloodPressureState: ActionGenerationBloodPressureState {
        ActionGenerationBloodPressureState(reading: latestTodayReading)
    }

    private var isExerciseSafetyBlocked: Bool {
        ActionGenerationSafetyPolicy.isBlocked(hasDiscomfort: hasDiscomfort)
    }

    private var recommendedExercises: [LowBarrierExercise] {
        ExerciseRecommendationEngine.recommendations(
            sceneTitle: scene,
            energyTitle: energy,
            contextTitles: contexts,
            limit: 4
        )
    }

    private var selectedCurrentExercise: LowBarrierExercise? {
        recommendedExercises.first { $0.id == currentExerciseId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                        ActionPageTitle(
                            title: "行动生成",
                            subtitle: "Action Studio",
                            subtitleFont: .subheadline.weight(.medium)
                        )

                        DSCard(
                            padding: DSTheme.Spacing.small,
                            backgroundColor: DSTheme.Color.primary
                        ) {
                            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                                HStack(spacing: 8) {
                                    Label("今日最新血压", systemImage: "heart.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Label(bloodPressureState.title, systemImage: bloodPressureState.systemImage)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(bloodPressureState.tint)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(.white)
                                        .clipShape(Capsule())
                                }

                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text(latestTodayReading.map { "\($0.systolic) / \($0.diastolic)" } ?? "-- / --")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("mmHg")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.86))
                                }

                            }
                        }

                        LowBarrierExerciseGenerationCard(
                            scene: $scene,
                            energy: $energy,
                            contexts: $contexts,
                            hasDiscomfort: $hasDiscomfort,
                            isSafetyBlocked: isExerciseSafetyBlocked,
                            onContinue: {
                                ensureCurrentExerciseSelection()
                                activeSheet = .lowBarrierExercise
                            }
                        )

                        Button {
                            activeSheet = .preference
                        } label: {
                            HStack(spacing: DSTheme.Spacing.small) {
                                Image(systemName: "figure.run")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.primary)
                                    .frame(width: 38, height: 38)
                                    .background(DSTheme.Color.primarySoft)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("记录自定义运动")
                                        .font(.headline)
                                        .foregroundStyle(DSTheme.Color.textPrimary)

                                    Text("填写运动名称和时间，加入今日行动")
                                        .font(.caption)
                                        .foregroundStyle(DSTheme.Color.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }
                            .padding(DSTheme.Spacing.medium)
                            .background(.white.opacity(0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)

                        HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(DSTheme.Color.primary)

                            Text("系统将主动推荐中低强度、低门槛运动，并在饮食时间提供低盐清单提醒。")
                                .font(.caption)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        }
                        .padding(DSTheme.Spacing.medium)
                        .background(DSTheme.Color.primarySoft.opacity(0.84))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    }
                    .padding(DSTheme.Spacing.large)
                    .padding(.bottom, 170)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .preference:
                    PreferenceMovementSheet(
                        customMovementName: $customMovementName,
                        startTime: $preferenceStartTime,
                        endTime: $preferenceEndTime,
                        isSafetyBlocked: isExerciseSafetyBlocked,
                        onClose: {
                            activeSheet = nil
                        }
                    ) {
                        generatePreferenceMovement()
                        activeSheet = nil
                    }
                case .lowBarrierExercise:
                    LowBarrierExerciseSelectionSheet(
                        exerciseId: $currentExerciseId,
                        startTime: $currentTime,
                        endTime: $currentEndTime,
                        recommendations: recommendedExercises,
                        stateSummary: stateSummary,
                        isSafetyBlocked: isExerciseSafetyBlocked,
                        onClose: {
                            activeSheet = nil
                        },
                        onGenerate: {
                            generateCurrentMovement()
                            activeSheet = nil
                        }
                    )
                }
            }
            .onAppear(perform: ensureCurrentExerciseSelection)
            .onChange(of: scene) { _, _ in ensureCurrentExerciseSelection() }
            .onChange(of: energy) { _, _ in ensureCurrentExerciseSelection() }
            .onChange(of: contexts) { _, _ in ensureCurrentExerciseSelection() }
            .onChange(of: isExerciseSafetyBlocked) { wasBlocked, isBlocked in
                if !wasBlocked && isBlocked {
                    onSafetyBlock()
                }
            }
            .task(id: isExerciseSafetyBlocked) {
                if isExerciseSafetyBlocked {
                    onSafetyBlock()
                }
            }
        }
    }

    private var stateSummary: String {
        let contextText = contexts.sorted().joined(separator: "、")
        let statusText = contextText.isEmpty ? energy : "\(energy) · \(contextText)"
        return "\(scene) · \(statusText)"
    }

    private var generatedActionTitle: String {
        if contexts.contains("饭后") && selectedCurrentExercise?.name == "慢走" {
            return "饭后散步"
        }

        return selectedCurrentExercise?.name ?? "低门槛运动"
    }

    private func generateCurrentMovement() {
        guard !isExerciseSafetyBlocked,
              let selectedCurrentExercise else { return }
        let item = TodayActionItem.generatedMovement(
            title: generatedActionTitle,
            timeText: currentTime,
            duration: ExerciseTimeRange.durationMinutes(from: currentTime, to: currentEndTime),
            order: 99,
            exercise: selectedCurrentExercise,
            scene: scene,
            energy: energy,
            contexts: contexts.sorted()
        )
        onGenerateAction(item)
    }

    private func ensureCurrentExerciseSelection() {
        let recommendations = ExerciseRecommendationEngine.recommendations(
            sceneTitle: scene,
            energyTitle: energy,
            contextTitles: contexts
        )
        if !recommendations.contains(where: { $0.id == currentExerciseId }) {
            currentExerciseId = recommendations.first?.id ?? ""
        }
    }

    private func generatePreferenceMovement() {
        guard !isExerciseSafetyBlocked else { return }
        var item = TodayActionItem.generatedMovement(
            title: customMovementName.trimmingCharacters(in: .whitespacesAndNewlines),
            timeText: preferenceStartTime,
            duration: ExerciseTimeRange.durationMinutes(from: preferenceStartTime, to: preferenceEndTime),
            order: 100
        )
        item.type = .custom
        item.description = "保持轻量运动 \(item.durationMinutes) 分钟，不追求强度。"
        item.reason = TodayActionType.custom.reason
        onGenerateAction(item)
    }
}

private enum ActionGenerationSheet: String, Identifiable {
    case preference
    case lowBarrierExercise

    var id: String {
        rawValue
    }
}

enum ActionGenerationSafetyPolicy {
    static func isBlocked(hasDiscomfort: Bool) -> Bool {
        hasDiscomfort
    }
}

enum ActionGenerationBloodPressureState: Equatable {
    case noReading
    case reassuring
    case watch
    case repeatReading
    case needsAttention

    init(reading: BloodPressureReading?) {
        guard let reading else {
            self = .noReading
            return
        }

        if reading.systolic >= 180 || reading.diastolic >= 120 {
            self = .needsAttention
        } else if reading.systolic >= 160 || reading.diastolic >= 100 {
            self = .repeatReading
        } else if reading.systolic >= 120 || reading.diastolic >= 80 || reading.systolic < 90 || reading.diastolic < 60 {
            self = .watch
        } else {
            self = .reassuring
        }
    }

    var title: String {
        switch self {
        case .noReading: "今日暂无读数"
        case .reassuring: "读数较稳定"
        case .watch: "继续监测"
        case .repeatReading: "建议复测"
        case .needsAttention: "需要重视"
        }
    }

    var systemImage: String {
        switch self {
        case .noReading: "minus.circle.fill"
        case .reassuring: "checkmark.circle.fill"
        case .watch: "eye.circle.fill"
        case .repeatReading: "arrow.clockwise.circle.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .reassuring: DSTheme.Color.success
        case .noReading, .watch: DSTheme.Color.primary
        case .repeatReading, .needsAttention: DSTheme.Color.warning
        }
    }

    var guidance: String {
        switch self {
        case .noReading:
            "尚无今日读数；运动建议仅依据你填写的当前状态。"
        case .needsAttention:
            "请先安静休息并复测；如伴明显不适，请及时寻求医疗帮助。"
        case .reassuring, .watch:
            "按原计划每日监测；如有头晕、胸闷、心慌或明显不适，请先休息并复测。"
        case .repeatReading:
            "如有头晕、胸闷、心慌或明显不适，请先休息并复测。"
        }
    }
}

private struct ActionOption: Identifiable {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var assetImageName: String? = nil

    var id: String {
        title
    }
}

private struct LowBarrierExerciseGenerationCard: View {
    @Binding var scene: String
    @Binding var energy: String
    @Binding var contexts: Set<String>
    @Binding var hasDiscomfort: Bool
    let isSafetyBlocked: Bool
    let onContinue: () -> Void

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("生成低门槛运动", systemImage: "figure.walk.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                    Text("依次选择场景和当前状态，系统会即时更新推荐运动。")
                        .font(.caption)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepHeader(number: 1, title: "选择场景")
                LazyVGrid(columns: compactColumns, spacing: DSTheme.Spacing.small) {
                    ForEach(Self.sceneOptions) { option in
                        ActionChoiceTile(
                            title: option.title,
                            subtitle: option.subtitle,
                            systemImage: option.systemImage,
                            assetImageName: option.assetImageName,
                            tint: option.tint,
                            isSelected: scene == option.title
                        ) {
                            scene = option.title
                        }
                    }
                }

                stepHeader(number: 2, title: "选择当前状态")
                Text("精力状态  [单选]")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)

                HStack(spacing: DSTheme.Spacing.small) {
                    ForEach(Self.energyOptions) { option in
                        StatusChip(
                            title: option.title,
                            systemImage: option.systemImage,
                            tint: option.tint,
                            isSelected: energy == option.title
                        ) {
                            energy = option.title
                        }
                    }
                }

                Text("情景状态  [可多选]")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)

                LazyVGrid(columns: statusColumns, spacing: DSTheme.Spacing.small) {
                    ForEach(Self.contextOptions) { option in
                        StatusChip(
                            title: option.title,
                            systemImage: option.systemImage,
                            tint: option.tint,
                            isSelected: contexts.contains(option.title)
                        ) {
                            toggleContext(option.title)
                        }
                    }
                }

                HStack(spacing: DSTheme.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DSTheme.Color.warning)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("我有明显不适")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DSTheme.Color.textPrimary)
                        Text("选择后暂停生成运动，请先休息并复测。")
                            .font(.caption2)
                            .foregroundStyle(DSTheme.Color.textSecondary)
                    }

                    Spacer()
                    Toggle("", isOn: $hasDiscomfort)
                        .labelsHidden()
                }
                .padding(DSTheme.Spacing.small)
                .background(DSTheme.Color.primarySoft.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                if isSafetyBlocked {
                    Label("当前不生成运动：请先休息并复测。", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSTheme.Spacing.small)
                        .background(DSTheme.Color.warning.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }

                DSPrimaryButton(
                    isSafetyBlocked ? "请先休息并复测" : "选择运动和时间",
                    isDisabled: isSafetyBlocked,
                    action: onContinue
                )
                .accessibilityIdentifier("choose-low-barrier-exercise-and-time")
            }
        }
        .accessibilityIdentifier("low-barrier-exercise-generation")
    }

    private var compactColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var statusColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    private func stepHeader(number: Int, title: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(DSTheme.Color.primary)
                .clipShape(Circle())

            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(DSTheme.Color.textPrimary)
        }
    }

    private func toggleContext(_ title: String) {
        if title == ExerciseContext.noSpecialCondition.rawValue {
            contexts = [ExerciseContext.noSpecialCondition.rawValue]
            return
        }

        contexts.remove(ExerciseContext.noSpecialCondition.rawValue)
        if contexts.contains(title) {
            contexts.remove(title)
        } else {
            contexts.insert(title)
        }

        if contexts.isEmpty {
            contexts = [ExerciseContext.noSpecialCondition.rawValue]
        }
    }

    private static let sceneOptions = [
        ActionOption(title: "私人室内", subtitle: "家中", systemImage: "sofa.fill", tint: Color(red: 0.55, green: 0.62, blue: 0.83)),
        ActionOption(title: "公共室内", subtitle: "工位，教室", systemImage: "laptopcomputer", tint: DSTheme.Color.primary),
        ActionOption(title: "公共室外", subtitle: "广场，车站", systemImage: "building.2.fill", tint: Color(red: 0.50, green: 0.70, blue: 0.86)),
        ActionOption(title: "私人/开放室外", subtitle: "公园，庭院", systemImage: "tree.fill", tint: Color(red: 0.20, green: 0.58, blue: 0.36))
    ]

    private static let energyOptions = [
        ActionOption(title: "精力低", subtitle: "", systemImage: "face.dashed", tint: Color(red: 0.49, green: 0.60, blue: 0.78)),
        ActionOption(title: "精力一般", subtitle: "", systemImage: "face.smiling", tint: DSTheme.Color.primary),
        ActionOption(title: "精力较好", subtitle: "", systemImage: "face.smiling.fill", tint: DSTheme.Color.success)
    ]

    private static let contextOptions = [
        ActionOption(title: "饭后", subtitle: "", systemImage: "takeoutbag.and.cup.and.straw.fill", tint: DSTheme.Color.primary),
        ActionOption(title: "久坐后", subtitle: "", systemImage: "chair.fill", tint: Color(red: 0.40, green: 0.52, blue: 0.84)),
        ActionOption(title: "压力后", subtitle: "", systemImage: "lightbulb.fill", tint: Color(red: 0.64, green: 0.55, blue: 0.17)),
        ActionOption(title: "睡眠不足", subtitle: "", systemImage: "moon.fill", tint: Color(red: 0.33, green: 0.47, blue: 0.76)),
        ActionOption(title: "刚活动后", subtitle: "", systemImage: "figure.run", tint: DSTheme.Color.primary),
        ActionOption(title: "无特殊情况", subtitle: "", systemImage: "sun.max.fill", tint: Color(red: 0.90, green: 0.56, blue: 0.12))
    ]

}

private struct LowBarrierExerciseSelectionSheet: View {
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    @Binding var exerciseId: String
    @Binding var startTime: String
    @Binding var endTime: String
    let recommendations: [LowBarrierExercise]
    let stateSummary: String
    let isSafetyBlocked: Bool
    let onClose: () -> Void
    let onGenerate: () -> Void

    private var columns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                    HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("选择运动和时间")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                            Text(stateSummary)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DSTheme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(DSTheme.Color.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(DSTheme.Color.primarySoft.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭")
                    }

                    DSCard {
                        VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                            Text("推荐的低门槛运动")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                            Text("系统已根据场景和当前状态更新以下 4 项推荐。")
                                .font(.caption)
                                .foregroundStyle(DSTheme.Color.textSecondary)

                            LazyVGrid(columns: columns, spacing: DSTheme.Spacing.small) {
                                ForEach(recommendations) { option in
                                    ActionChoiceTile(
                                        title: option.name,
                                        subtitle: option.type.rawValue,
                                        systemImage: option.systemImageName,
                                        assetImageName: option.assetImageName(for: exercisePresentationSex),
                                        tint: option.type == .aerobic
                                            ? DSTheme.Color.primary
                                            : Color(red: 0.38, green: 0.52, blue: 0.78),
                                        isSelected: exerciseId == option.id
                                    ) {
                                        exerciseId = option.id
                                    }
                                }
                            }
                        }
                    }

                    DSCard {
                        VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                            Text("设置运动时间")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                            ExerciseTimeRangePicker(startTime: $startTime, endTime: $endTime)
                        }
                    }

                    DSPrimaryButton(
                        isSafetyBlocked ? "请先休息并复测" : "生成今日运动",
                        isDisabled: isSafetyBlocked || recommendations.isEmpty,
                        action: onGenerate
                    )
                    .accessibilityIdentifier("generate-low-barrier-exercise")
                }
                .padding(DSTheme.Spacing.large)
                .padding(.bottom, 24)
            }
            .background(DSTheme.Color.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}

private struct ActionSetupCard: View {
    let title: String
    let value: String
    let systemImage: String
    let illustration: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(tint)

                    Spacer()

                    Image(systemName: illustration)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.78))
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.10))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        Text(value)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DSTheme.Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DSTheme.Color.primary.opacity(0.7))
                    }
                }
            }
            .padding(DSTheme.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionPageTitle: View {
    let title: String
    let subtitle: String
    let subtitleFont: Font

    init(
        title: String,
        subtitle: String,
        subtitleFont: Font = .subheadline.weight(.semibold)
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleFont = subtitleFont
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

            Text(subtitle)
                .font(subtitleFont)
                .foregroundStyle(DSTheme.Color.textSecondary)
        }
    }
}

private struct ActionSheetHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(DSTheme.Color.primarySoft.opacity(0.7))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SceneSelectionSheet: View {
    @Binding var scene: String
    let onConfirm: () -> Void

    private let options = [
        ActionOption(title: "私人室内", subtitle: "家中", systemImage: "sofa.fill", tint: Color(red: 0.55, green: 0.62, blue: 0.83)),
        ActionOption(title: "公共室内", subtitle: "工位，教室", systemImage: "laptopcomputer", tint: DSTheme.Color.primary),
        ActionOption(title: "公共室外", subtitle: "广场，车站", systemImage: "building.2.fill", tint: Color(red: 0.50, green: 0.70, blue: 0.86)),
        ActionOption(title: "私人/开放室外", subtitle: "公园，庭院", systemImage: "tree.fill", tint: Color(red: 0.20, green: 0.58, blue: 0.36))
    ]

    var body: some View {
        SheetContent {
            ActionSheetHeader(title: "场景选择", subtitle: "系统会根据场景匹配低门槛运动", onClose: onConfirm)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSTheme.Spacing.small) {
                ForEach(options) { option in
                    ActionChoiceTile(
                        title: option.title,
                        subtitle: option.subtitle,
                        systemImage: option.systemImage,
                        assetImageName: option.assetImageName,
                        tint: option.tint,
                        isSelected: scene == option.title
                    ) {
                        scene = option.title
                    }
                }
            }

            DSPrimaryButton("确认场景", action: onConfirm)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StatusSelectionSheet: View {
    @Binding var energy: String
    @Binding var contexts: Set<String>
    @Binding var hasDiscomfort: Bool
    let onConfirm: () -> Void

    private let energyOptions = [
        ActionOption(title: "精力低", subtitle: "", systemImage: "face.dashed", tint: Color(red: 0.49, green: 0.60, blue: 0.78)),
        ActionOption(title: "精力一般", subtitle: "", systemImage: "face.smiling", tint: DSTheme.Color.primary),
        ActionOption(title: "精力较好", subtitle: "", systemImage: "face.smiling.fill", tint: DSTheme.Color.success)
    ]

    private let contextOptions = [
        ActionOption(title: "饭后", subtitle: "", systemImage: "takeoutbag.and.cup.and.straw.fill", tint: DSTheme.Color.primary),
        ActionOption(title: "久坐后", subtitle: "", systemImage: "chair.fill", tint: Color(red: 0.40, green: 0.52, blue: 0.84)),
        ActionOption(title: "压力后", subtitle: "", systemImage: "lightbulb.fill", tint: Color(red: 0.64, green: 0.55, blue: 0.17)),
        ActionOption(title: "睡眠不足", subtitle: "", systemImage: "moon.fill", tint: Color(red: 0.33, green: 0.47, blue: 0.76)),
        ActionOption(title: "刚活动后", subtitle: "", systemImage: "figure.run", tint: DSTheme.Color.primary),
        ActionOption(title: "无特殊情况", subtitle: "", systemImage: "sun.max.fill", tint: Color(red: 0.90, green: 0.56, blue: 0.12))
    ]

    var body: some View {
        SheetContent {
            ActionSheetHeader(title: "状态选择", subtitle: "用于判断强度和安全边界", onClose: onConfirm)

            SheetSectionTitle("精力状态", systemImage: "bolt.circle.fill")
            HStack(spacing: DSTheme.Spacing.small) {
                ForEach(energyOptions) { option in
                    StatusChip(
                        title: option.title,
                        systemImage: option.systemImage,
                        tint: option.tint,
                        isSelected: energy == option.title
                    ) {
                        energy = option.title
                    }
                }
            }

            SheetSectionTitle("情景状态  [可多选]", systemImage: "person.crop.circle.badge.checkmark")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DSTheme.Spacing.small) {
                ForEach(contextOptions) { option in
                    StatusChip(
                        title: option.title,
                        systemImage: option.systemImage,
                        tint: option.tint,
                        isSelected: contexts.contains(option.title)
                    ) {
                        if option.title == ExerciseContext.noSpecialCondition.rawValue {
                            contexts = [ExerciseContext.noSpecialCondition.rawValue]
                        } else {
                            contexts.remove(ExerciseContext.noSpecialCondition.rawValue)
                            if contexts.contains(option.title) {
                                contexts.remove(option.title)
                            } else {
                                contexts.insert(option.title)
                            }

                            if contexts.isEmpty {
                                contexts = [ExerciseContext.noSpecialCondition.rawValue]
                            }
                        }
                    }
                }
            }

            SheetSectionTitle("安全状态", systemImage: "shield.lefthalf.filled")
            HStack(spacing: DSTheme.Spacing.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DSTheme.Color.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("我有明显不适")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Text("如选择此项，系统将优先建议休息与复测。")
                        .font(.caption2)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $hasDiscomfort)
                    .labelsHidden()
            }
            .padding(DSTheme.Spacing.medium)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            DSPrimaryButton("确认状态", action: onConfirm)
        }
        .presentationDetents([.large])
    }
}

private struct PreferenceMovementSheet: View {
    @Binding var customMovementName: String
    @Binding var startTime: String
    @Binding var endTime: String
    let isSafetyBlocked: Bool
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        SheetContent {
            ActionSheetHeader(
                title: "记录自定义运动",
                subtitle: "填写运动名称和时间，保存后会加入今日行动",
                onClose: onClose
            )

            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                Text("运动名称")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)

                TextField("例如：骑车", text: $customMovementName)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(DSTheme.Color.textPrimary)
                    .tint(DSTheme.Color.primary)
                    .padding(DSTheme.Spacing.medium)
                    .background(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DSTheme.Color.border, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            ExerciseTimeRangePicker(startTime: $startTime, endTime: $endTime)

            Label("保存后会按所选时间生成一张运动卡片，并显示在今日行动的时间轴中。", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .padding(DSTheme.Spacing.medium)
                .background(DSTheme.Color.primarySoft.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if isSafetyBlocked {
                Label("当前状态不适合直接生成今日运动，请先休息并复测。", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.warning)
            }

            DSPrimaryButton(
                "保存偏好运动",
                isDisabled: customMovementName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSafetyBlocked,
                action: onConfirm
            )
        }
        .presentationDetents([.large])
    }
}

private struct SheetContent<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                    content
                }
                .padding(DSTheme.Spacing.large)
            }
        }
    }
}

private struct SheetSectionTitle: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(DSTheme.Color.primary)
    }
}

private struct ActionChoiceTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var assetImageName: String? = nil
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        if assetImageName == nil {
                            tint.opacity(0.12)
                        } else {
                            Color.white
                        }

                        if let assetImageName {
                            Image(assetImageName)
                                .resizable()
                                .scaledToFit()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DSTheme.Color.primary)
                            .padding(6)
                    }
                }

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textPrimary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(DSTheme.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: subtitle.isEmpty ? 132 : 152, alignment: .topLeading)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: isSelected ? 1.5 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StatusChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : tint)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : DSTheme.Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary : DSTheme.Color.border, lineWidth: isSelected ? 1.4 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum TodayActionRoute: Hashable {
    case detail(UUID)
}

private struct TodaySummaryCard: View {
    let imageName: String
    let title: String
    let value: String
    let suffix: String

    var body: some View {
        HStack(spacing: DSTheme.Spacing.small) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)

                    Text(suffix)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSTheme.Spacing.medium)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

private struct TodayTreeTimelineView: View {
    let items: [TodayActionItem]
    let now: Date
    let layout: TimelineLayout
    let onSelect: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let axisX = size.width * 0.5
            let lanePadding: CGFloat = 14
            let centerGutter = min(78, max(62, size.width * 0.2))
            let cardWidth = max((size.width - lanePadding * 2 - centerGutter) / 2, 104)
            let leftCardX = lanePadding + cardWidth / 2
            let rightCardX = size.width - lanePadding - cardWidth / 2
            let axisHeight = max(
                layout.contentHeight - TimelinePositioner.topInset - TimelinePositioner.bottomInset,
                1
            )

            ZStack(alignment: .topLeading) {
                TimelineLaneHeader(
                    title: "行动及血压测量",
                    systemImage: "heart.text.square.fill",
                    tint: Color(red: 0.16, green: 0.34, blue: 0.82)
                )
                .frame(width: cardWidth)
                .position(x: leftCardX, y: 30)

                TimelineLaneHeader(
                    title: "三餐",
                    systemImage: "fork.knife.circle.fill",
                    tint: Color(red: 0.58, green: 0.60, blue: 0.34)
                )
                .frame(width: cardWidth)
                .position(x: rightCardX, y: 30)

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 5, height: axisHeight)
                        .overlay {
                            Rectangle()
                                .fill(DSTheme.Color.primary.opacity(0.28))
                                .frame(width: 1.5)
                        }
                }
                .position(x: axisX, y: TimelinePositioner.topInset + axisHeight / 2)

                ForEach(layout.timeRows) { row in
                    TimeBubble(
                        text: TodayActionItem.timeFormatter.string(from: row.date),
                        tint: row.tint
                    )
                    .position(x: axisX, y: row.y)
                }

                ForEach(items.sorted(by: TimelinePositioner.itemSort)) { item in
                    let y = layout.itemY[item.id] ?? TimelinePositioner.topInset
                    let cardHeight = layout.itemHeight[item.id] ?? TimelinePositioner.cardHeight(for: item)
                    let isMeal = item.type == .diet
                    let cardX = isMeal ? rightCardX : leftCardX
                    let cardEdgeX = isMeal ? cardX - cardWidth / 2 + 6 : cardX + cardWidth / 2 - 6
                    let axisEdgeX = isMeal ? axisX + 28 : axisX - 28

                    TimelineConnector(
                        fromX: axisEdgeX,
                        toX: cardEdgeX,
                        y: y,
                        tint: item.type.accent
                    )
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .allowsHitTesting(false)

                    DesignActionCard(
                        item: item,
                        usesCompactHeader: cardWidth < 145
                    )
                        .frame(width: cardWidth, height: cardHeight)
                        .position(x: cardX, y: y)
                        .accessibilityIdentifier(accessibilityIdentifier(for: item, isMeal: isMeal))
                        .accessibilityLabel(accessibilityLabel(for: item, isMeal: isMeal))
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture {
                            onSelect(item.id)
                    }
                }

                CurrentTimeGlow(
                    timeText: TodayActionItem.timeFormatter.string(from: now),
                    tint: Color(red: 1.0, green: 0.55, blue: 0.14)
                )
                .position(x: axisX, y: layout.currentY)
            }
        }
    }

    private func accessibilityIdentifier(for item: TodayActionItem, isMeal: Bool) -> String {
        if isMeal {
            return "today.meal.\(MealKind(actionTitle: item.title)?.rawValue ?? "unknown")"
        }
        if item.type == .bpRecheck, item.title.contains("早晨") {
            return "today.bp.morning"
        }
        if item.type == .bpRecheck, item.title.contains("晚间") {
            return "today.bp.evening"
        }
        return "today.action.\(item.id.uuidString)"
    }

    private func accessibilityLabel(for item: TodayActionItem, isMeal: Bool) -> String {
        guard isMeal, let rule = MealTimingRule(actionTitle: item.title) else {
            return item.title
        }
        return "\(item.title)，建议时间，\(rule.message)"
    }
}

struct TimelineLayout {
    let itemY: [UUID: CGFloat]
    let itemHeight: [UUID: CGFloat]
    let timeRows: [TimelineTimeRow]
    let currentY: CGFloat
    let contentHeight: CGFloat
}

struct TimelineTimeRow: Identifiable {
    let id: Int
    let date: Date
    let y: CGFloat
    let tint: Color
}

struct TimelinePositioner {
    static let topInset: CGFloat = 62
    static let bottomInset: CGFloat = 58
    private static let sameLaneGap: CGFloat = 10
    private static let currentRowHeight: CGFloat = 46
    private static let minimumContentHeight: CGFloat = 640

    static func layout(items: [TodayActionItem], now: Date) -> TimelineLayout {
        let groupedItems = Dictionary(grouping: items) { minuteKey(for: $0.scheduledStartAt) }
        var entries = groupedItems.map { key, group in
            TimelineLayoutEntry.actions(
                key: key,
                date: group.map(\.scheduledStartAt).min() ?? Date(),
                items: group.sorted(by: itemSort)
            )
        }
        entries.append(.current(now))
        entries.sort(by: entrySort)

        var itemY: [UUID: CGFloat] = [:]
        var itemHeight: [UUID: CGFloat] = [:]
        var timeRows: [TimelineTimeRow] = []
        var currentY = topInset + currentRowHeight / 2
        var cursor = topInset
        var previousDate: Date?

        for entry in entries {
            if let previousDate {
                cursor += chronologicalGap(from: previousDate, to: entry.date)
            }

            switch entry {
            case .actions(let key, let date, let groupItems):
                let leftItems = groupItems.filter { $0.type != .diet }
                let rightItems = groupItems.filter { $0.type == .diet }
                let leftHeight = laneHeight(for: leftItems)
                let rightHeight = laneHeight(for: rightItems)
                let rowHeight = max(leftHeight, rightHeight, 48)

                assign(leftItems, rowTop: cursor, rowHeight: rowHeight, itemY: &itemY, itemHeight: &itemHeight)
                assign(rightItems, rowTop: cursor, rowHeight: rowHeight, itemY: &itemY, itemHeight: &itemHeight)

                let tint = groupItems.allSatisfy { $0.displayStatus == .completed }
                    ? DSTheme.Color.success
                    : DSTheme.Color.primary
                timeRows.append(
                    TimelineTimeRow(
                        id: key,
                        date: date,
                        y: cursor + rowHeight / 2,
                        tint: tint
                    )
                )
                cursor += rowHeight

            case .current:
                currentY = cursor + currentRowHeight / 2
                cursor += currentRowHeight
            }

            previousDate = entry.date
        }

        return TimelineLayout(
            itemY: itemY,
            itemHeight: itemHeight,
            timeRows: timeRows,
            currentY: currentY,
            contentHeight: max(cursor + bottomInset, minimumContentHeight)
        )
    }

    static func cardHeight(for item: TodayActionItem) -> CGFloat {
        switch item.type {
        case .diet where item.displayStatus == .completed && item.adviceText != nil:
            return 312
        case .diet:
            return 232
        case .bpRecheck where item.bloodPressureText != nil:
            return 158
        case .bpRecheck:
            return 142
        case .rest, .hydration, .sleep, .custom:
            return 154
        case .walk:
            return 142
        }
    }

    static func itemSort(_ lhs: TodayActionItem, _ rhs: TodayActionItem) -> Bool {
        if lhs.scheduledStartAt == rhs.scheduledStartAt {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.scheduledStartAt < rhs.scheduledStartAt
    }

    private static func minuteKey(for date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / 60)
    }

    private static func laneHeight(for items: [TodayActionItem]) -> CGFloat {
        guard !items.isEmpty else { return 0 }
        return items.reduce(CGFloat.zero) { $0 + cardHeight(for: $1) }
            + CGFloat(max(items.count - 1, 0)) * sameLaneGap
    }

    private static func assign(
        _ items: [TodayActionItem],
        rowTop: CGFloat,
        rowHeight: CGFloat,
        itemY: inout [UUID: CGFloat],
        itemHeight: inout [UUID: CGFloat]
    ) {
        let stackHeight = laneHeight(for: items)
        var offset = rowTop + max((rowHeight - stackHeight) / 2, 0)

        for item in items {
            let height = cardHeight(for: item)
            itemY[item.id] = offset + height / 2
            itemHeight[item.id] = height
            offset += height + sameLaneGap
        }
    }

    private static func chronologicalGap(from earlier: Date, to later: Date) -> CGFloat {
        let minutes = max(later.timeIntervalSince(earlier) / 60, 0)
        return min(18, max(8, CGFloat(minutes) * 0.08))
    }

    private static func entrySort(_ lhs: TimelineLayoutEntry, _ rhs: TimelineLayoutEntry) -> Bool {
        if minuteKey(for: lhs.date) == minuteKey(for: rhs.date) {
            return lhs.sortRank < rhs.sortRank
        }
        return lhs.date < rhs.date
    }
}

private enum TimelineLayoutEntry {
    case actions(key: Int, date: Date, items: [TodayActionItem])
    case current(Date)

    var date: Date {
        switch self {
        case .actions(_, let date, _), .current(let date):
            return date
        }
    }

    var sortRank: Int {
        switch self {
        case .actions:
            return 0
        case .current:
            return 1
        }
    }
}

private struct TimelineLaneHeader: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

private struct DesignActionCard: View {
    let item: TodayActionItem
    let usesCompactHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader

            statusPill

            switch item.type {
            case .bpRecheck:
                if let bloodPressureText = item.bloodPressureText {
                    metricPill(bloodPressureText, suffix: "mmHg")
                } else {
                    Text("点击前往记录")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                }
            case .diet:
                mealTimingRuleBox
                if item.displayStatus == .completed, item.adviceText != nil {
                    adviceBox
                }
            case .walk:
                EmptyView()
            case .rest, .hydration, .sleep, .custom:
                Text(item.description)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DSTheme.Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(
            maxWidth: .infinity,
            minHeight: item.type == .diet && item.displayStatus == .completed ? 288 : 116,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var cardHeader: some View {
        if usesCompactHeader {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    titleText
                        .layoutPriority(1)

                    Spacer(minLength: 2)

                    TimelineActionArtwork(item: item)
                        .frame(
                            width: item.type == .diet ? 46 : 44,
                            height: item.type == .diet ? 44 : 48
                        )
                }

                if item.type != .bpRecheck && item.type != .diet {
                    subtitleText
                }
            }
        } else {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 5) {
                    titleText
                    if item.type != .bpRecheck && item.type != .diet {
                        subtitleText
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                TimelineActionArtwork(item: item)
                    .frame(
                        width: item.type == .diet ? 58 : 54,
                        height: item.type == .diet ? 54 : 58
                    )
            }
        }
    }

    private var titleText: some View {
        Text(item.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.40))
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subtitleText: some View {
        Text(item.timelineSubtitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusPill: some View {
        Text(actionStatusTitle)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(item.displayStatus.tint.opacity(0.18))
            .clipShape(Capsule())
    }

    private var actionStatusTitle: String {
        if (item.type == .diet || item.isCatalogExercise),
           item.displayStatus != .completed,
           item.displayStatus != .skipped {
            return "开始"
        }
        return item.displayStatus.title
    }

    private var statusTextColor: Color {
        switch item.displayStatus {
        case .completed:
            return Color(red: 0.06, green: 0.40, blue: 0.16)
        case .pending, .inProgress:
            return DSTheme.Color.primary
        case .skipped:
            return DSTheme.Color.textSecondary
        case .missed:
            return Color(red: 0.70, green: 0.33, blue: 0.08)
        }
    }

    private func metricPill(_ value: String, suffix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.caption.weight(.bold))
            Text(suffix)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var adviceBox: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AI分析与建议")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

            Text(item.adviceText ?? item.description)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DSTheme.Color.textPrimary)
                .lineLimit(4)
                .minimumScaleFactor(0.78)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var mealTimingRuleBox: some View {
        if let rule = MealTimingRule(actionTitle: item.title) {
            VStack(alignment: .leading, spacing: 4) {
                Text("建议时间")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 0.48, green: 0.30, blue: 0.04))

                Text(rule.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.30, green: 0.23, blue: 0.10))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.0, green: 239.0 / 255.0, blue: 199.0 / 255.0))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }
}

struct MealTimingRule: Equatable {
    let timeRange: String
    let message: String

    init?(actionTitle: String) {
        if actionTitle.contains("早餐") {
            timeRange = "07:00–09:00"
            message = "晨间血压后即可进餐；餐后至少 1 小时再运动。"
        } else if actionTitle.contains("午餐") {
            timeRange = "12:00–14:00"
            message = "餐后至少 1 小时再运动。"
        } else if actionTitle.contains("晚餐") {
            timeRange = "18:00–20:00"
            message = "餐后至少 1 小时再运动；运动后至少 30 分钟再测睡前血压。"
        } else {
            return nil
        }
    }
}

private struct TimelineActionArtwork: View {
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    let item: TodayActionItem

    var body: some View {
        if let assetName = item.timelineArtworkAssetName(for: exercisePresentationSex) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            ActionIllustration(type: item.type)
        }
    }
}

private struct ActionIllustration: View {
    let type: TodayActionType

    var body: some View {
        ZStack {
            Circle()
                .fill(type.accent.opacity(0.12))

            Image(systemName: type.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(type.accent)
        }
    }
}

private struct TimeBubble: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: tint.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

private struct TimelineConnector: View {
    let fromX: CGFloat
    let toX: CGFloat
    let y: CGFloat
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: fromX, y: y))
                path.addLine(to: CGPoint(x: toX, y: y))
            }
            .stroke(
                tint.opacity(0.72),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 4])
            )

            Circle()
                .fill(tint.opacity(0.88))
                .frame(width: 7, height: 7)
                .position(x: toX, y: y)
        }
    }
}

private struct CurrentTimeGlow: View {
    let timeText: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 58, height: 58)
                .blur(radius: 2)

            Text(timeText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(tint)
                .clipShape(Capsule())
                .shadow(color: tint.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("当前时间 \(timeText)")
    }
}

private struct TreeStageBackground: View {
    let completionRate: Double

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
    }

    private var assetName: String {
        switch completionRate {
        case ..<0.2:
            return "TreeGrowth0_20"
        case ..<0.4:
            return "TreeGrowth20_40"
        case ..<0.6:
            return "TreeGrowth40_60"
        case ..<0.8:
            return "TreeGrowth60_80"
        default:
            return "TreeGrowth80_100"
        }
    }
}

private struct TimelineBranch: Shape {
    let toLeft: Bool

    func path(in rect: CGRect) -> Path {
        Path { path in
            if toLeft {
                path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.addCurve(
                    to: CGPoint(x: rect.minX, y: rect.midY),
                    control1: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY),
                    control2: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY)
                )
            } else {
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addCurve(
                    to: CGPoint(x: rect.maxX, y: rect.midY),
                    control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY),
                    control2: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY)
                )
            }
        }
    }
}

private struct ExerciseRecordSheet: View {
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    let item: TodayActionItem
    let onUpdate: (ExerciseTimerUpdate) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var status: TodayActionStatus
    @State private var actualStartedAt: Date?
    @State private var timerLastResumedAt: Date?
    @State private var timerAccumulatedSeconds: Int
    @State private var actualEndedAt: Date?
    @State private var actualDurationSeconds: Int?
    @State private var completionMode: ExerciseCompletionMode?
    @State private var isConfirmingEarlyEnd = false
    @State private var isConfirmingDelete = false

    init(
        item: TodayActionItem,
        onUpdate: @escaping (ExerciseTimerUpdate) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.item = item
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onClose = onClose
        _status = State(initialValue: item.status)
        _actualStartedAt = State(initialValue: item.actualStartedAt)
        _timerLastResumedAt = State(initialValue: item.timerLastResumedAt)
        _timerAccumulatedSeconds = State(initialValue: item.timerAccumulatedSeconds)
        _actualEndedAt = State(initialValue: item.actualEndedAt)
        _actualDurationSeconds = State(initialValue: item.actualDurationSeconds)
        _completionMode = State(initialValue: item.completionMode)
    }

    private var catalogExercise: LowBarrierExercise? {
        guard let exerciseId = item.exerciseId else { return nil }
        return LowBarrierExerciseCatalog.exercise(id: exerciseId)
    }

    private var movementSteps: [String] {
        catalogExercise?.movementAdviceSteps ?? adviceLines(from: item.exerciseMovementAdvice ?? item.description)
    }

    private var intensityAdviceSteps: [String] {
        catalogExercise?.intensityAdviceSteps ?? adviceLines(from: item.exerciseIntensityAdvice ?? "保持自然呼吸；如有明显不适，请停止并休息。")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                    header
                    exerciseArtwork.frame(maxWidth: .infinity).frame(height: 230)
                    timerSection
                    advicePanel(title: "怎么做", tint: Color(red: 0.88, green: 0.94, blue: 1.0), steps: movementSteps)
                    advicePanel(title: "强度建议", tint: Color(red: 1.0, green: 0.94, blue: 0.78), steps: intensityAdviceSteps)
                    actionButtons
                    deleteButton
                }
                .padding(DSTheme.Spacing.large)
                .padding(.bottom, 24)
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .alert("提前结束运动？", isPresented: $isConfirmingEarlyEnd) {
            Button("取消", role: .cancel) {}
            Button("提前结束") { finish(mode: .endedEarly) }
        } message: {
            Text("实际运动时长会被记录，便于后续趋势研究。")
        }
        .alert("删除今日行动？", isPresented: $isConfirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive, action: onDelete)
        } message: {
            Text("这个行动将从今天的时间轴移除；后台会保留匿名删除记录用于研究。")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 30, weight: .bold)).foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                Text("\(item.durationMinutes)分钟").font(.title3.weight(.semibold)).foregroundStyle(DSTheme.Color.textPrimary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.headline.weight(.bold)).foregroundStyle(DSTheme.Color.textPrimary)
                    .frame(width: 40, height: 40).background(DSTheme.Color.primarySoft.opacity(0.7)).clipShape(Circle())
            }.buttonStyle(.plain).accessibilityLabel("关闭")
        }
    }

    private var timerSection: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let elapsed = elapsedSeconds(at: context.date)
            let remaining = max(item.durationMinutes * 60 - elapsed, 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(timerTitle(remaining: remaining), systemImage: timerIcon)
                        .font(.headline).foregroundStyle(timerTint)
                    Spacer()
                    if status == .inProgress {
                        Text(timeText(remaining > 0 ? remaining : elapsed - item.durationMinutes * 60, prefix: remaining > 0 ? "" : "+"))
                            .font(.system(.title3, design: .monospaced).weight(.bold)).foregroundStyle(timerTint)
                    }
                }
                if status == .inProgress && remaining == 0 {
                    Text("计划时长已完成，请确认完成或继续运动。")
                        .font(.subheadline).foregroundStyle(DSTheme.Color.textSecondary)
                }
            }
            .padding(DSTheme.Spacing.medium).background(DSTheme.Color.primarySoft.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder private var actionButtons: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let elapsed = elapsedSeconds(at: context.date)
            let timedOut = elapsed >= item.durationMinutes * 60
            switch status {
            case .completed:
                DSPrimaryButton("关闭", action: onClose)
            case .inProgress:
                VStack(spacing: 10) {
                    if timedOut {
                        DSPrimaryButton("完成本次运动", systemImage: "checkmark.circle.fill") { finish(mode: .timerCompleted) }
                        DSSecondaryButton("继续运动", systemImage: "figure.run") { onClose() }
                    } else if timerLastResumedAt == nil {
                        DSPrimaryButton("继续计时", systemImage: "play.fill", action: resume)
                    } else {
                        DSPrimaryButton("暂停计时", systemImage: "pause.fill", action: pause)
                    }
                    Button("提前结束") { isConfirmingEarlyEnd = true }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(DSTheme.Color.textSecondary)
                }
            case .pending, .missed, .skipped:
                DSPrimaryButton("开始运动", systemImage: "play.fill", action: start)
            }
        }
    }

    private var deleteButton: some View {
        Button { isConfirmingDelete = true } label: {
            Label("删除今日行动", systemImage: "trash")
                .font(.headline).foregroundStyle(.red).frame(maxWidth: .infinity).frame(height: 52)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.red, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }

    private var timerIcon: String { status == .completed ? "checkmark.circle.fill" : status == .inProgress ? "timer" : "play.circle" }
    private var timerTint: Color { status == .completed ? DSTheme.Color.success : DSTheme.Color.primary }
    private func timerTitle(remaining: Int) -> String {
        if status == .completed { return "已记录" }
        if status == .inProgress { return remaining == 0 ? "时间已到" : timerLastResumedAt == nil ? "已暂停" : "运动计时中" }
        return "尚未开始"
    }

    private func elapsedSeconds(at date: Date) -> Int {
        timerAccumulatedSeconds + (timerLastResumedAt.map { max(Int(date.timeIntervalSince($0)), 0) } ?? 0)
    }

    private func start() {
        let now = Date(); status = .inProgress; actualStartedAt = now; timerLastResumedAt = now; timerAccumulatedSeconds = 0
        actualEndedAt = nil; actualDurationSeconds = nil; completionMode = nil
        publish(); Task { await ExerciseTimerNotificationService.schedule(for: item, remainingSeconds: item.durationMinutes * 60) }
    }

    private func pause() {
        timerAccumulatedSeconds = elapsedSeconds(at: Date()); timerLastResumedAt = nil
        ExerciseTimerNotificationService.cancel(for: item.id); publish()
    }

    private func resume() {
        let remaining = max(item.durationMinutes * 60 - timerAccumulatedSeconds, 0)
        timerLastResumedAt = Date(); publish()
        if remaining > 0 { Task { await ExerciseTimerNotificationService.schedule(for: item, remainingSeconds: remaining) } }
    }

    private func finish(mode: ExerciseCompletionMode) {
        let now = Date(); let elapsed = elapsedSeconds(at: now)
        status = .completed; timerAccumulatedSeconds = elapsed; timerLastResumedAt = nil
        actualEndedAt = now; actualDurationSeconds = elapsed; completionMode = mode
        ExerciseTimerNotificationService.cancel(for: item.id); publish(); onClose()
    }

    private func publish() {
        onUpdate(ExerciseTimerUpdate(status: status, actualStartedAt: actualStartedAt, timerLastResumedAt: timerLastResumedAt,
            timerAccumulatedSeconds: timerAccumulatedSeconds, actualEndedAt: actualEndedAt,
            actualDurationSeconds: actualDurationSeconds, completionMode: completionMode))
    }

    @ViewBuilder private var exerciseArtwork: some View {
        if let assetName = catalogExercise?.assetImageName(for: exercisePresentationSex) ?? item.timelineArtworkAssetName(for: exercisePresentationSex) {
            Image(assetName).resizable().scaledToFit().accessibilityHidden(true)
        } else {
            Image(systemName: "figure.walk").font(.system(size: 104)).foregroundStyle(DSTheme.Color.primary)
        }
    }

    private func adviceLines(from advice: String) -> [String] {
        advice.split(whereSeparator: \.isNewline).map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func advicePanel(title: String, tint: Color, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: 8) { Text("•"); Text(step).fixedSize(horizontal: false, vertical: true) }
                    .foregroundStyle(DSTheme.Color.textPrimary)
            }
        }.padding(DSTheme.Spacing.medium).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timeText(_ seconds: Int, prefix: String) -> String {
        String(format: "%@%02d:%02d", prefix, seconds / 60, seconds % 60)
    }
}

struct ExerciseTimerUpdate: Equatable {
    let status: TodayActionStatus
    let actualStartedAt: Date?
    let timerLastResumedAt: Date?
    let timerAccumulatedSeconds: Int
    let actualEndedAt: Date?
    let actualDurationSeconds: Int?
    let completionMode: ExerciseCompletionMode?
}

enum ExerciseCompletionMode: String, Codable, Hashable {
    case timerCompleted = "timer_completed"
    case endedEarly = "ended_early"
    case manualCompleted = "manual_completed"
}

private struct TodayActionDetailView: View {
    let item: TodayActionItem
    let effectiveStatus: TodayActionStatus
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            TreeStageBackground(completionRate: item.status == .completed ? 0.8 : 0.25)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                    DSSectionHeader(item.title, subtitle: item.timeRangeText, systemImage: item.type.systemImage)

                    DSCard {
                        VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                            HStack(spacing: DSTheme.Spacing.small) {
                                Image(systemName: effectiveStatus.systemImage)
                                    .foregroundStyle(effectiveStatus.tint)

                                Text(effectiveStatus.title)
                                    .font(.headline)
                                    .foregroundStyle(effectiveStatus.tint)

                                Spacer()

                                Text("\(item.durationMinutes) 分钟")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }

                            Text(detailDescription)
                                .font(.body)
                                .foregroundStyle(DSTheme.Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(item.reason)
                                .font(.subheadline)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(spacing: DSTheme.Spacing.small) {
                        DSPrimaryButton("标记完成", systemImage: "checkmark.circle.fill", isDisabled: item.status == .completed) {
                            onComplete()
                        }
                    }
                }
                .padding(DSTheme.Spacing.large)
                .padding(.bottom, 130)
            }
        }
        .navigationTitle("行动详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailDescription: String {
        item.description.replacingOccurrences(of: "保持轻松步行", with: "保持轻量运动")
    }
}

private struct GeneratePreviewRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: DSTheme.Spacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(DSTheme.Color.primary)
                .frame(width: 34, height: 34)
                .background(DSTheme.Color.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textPrimary)
            }
        }
    }
}

private struct PlanPreviewPill: View {
    let title: String
    let time: String
    let icon: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)

            Spacer()

            Text(time)
                .font(.caption.weight(.bold))
                .foregroundStyle(DSTheme.Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DSTheme.Color.primarySoft)
                .clipShape(Capsule())
        }
    }
}

private struct TodayTimelineRange {
    let start: Date
    let end: Date

    init(items: [TodayActionItem], now: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let defaultStart = calendar.date(byAdding: .hour, value: 7, to: startOfDay) ?? now
        let defaultEnd = calendar.date(byAdding: .hour, value: 22, to: startOfDay) ?? now
        let earliest = items.map(\.scheduledStartAt).min() ?? defaultStart
        let latest = items.map(\.scheduledEndAt).max() ?? defaultEnd

        start = min(defaultStart, earliest)
        end = max(defaultEnd, latest)
    }

    func progress(for date: Date) -> CGFloat {
        let total = max(end.timeIntervalSince(start), 1)
        let raw = date.timeIntervalSince(start) / total
        return CGFloat(min(max(raw, 0), 1))
    }
}

struct TodayActionItem: Identifiable, Hashable {
    let id: UUID
    var type: TodayActionType
    var title: String
    var description: String
    var reason: String
    var scheduledStartAt: Date
    var scheduledEndAt: Date
    var durationMinutes: Int
    var status: TodayActionStatus
    var displayStatus: TodayActionStatus
    var completedAt: Date?
    var sortOrder: Int
    var bloodPressureText: String?
    var adviceText: String?
    var exerciseId: String?
    var exerciseScene: String?
    var exerciseEnergy: String?
    var exerciseContexts: [String]
    var exerciseMovementAdvice: String?
    var exerciseIntensityAdvice: String?
    var actualStartedAt: Date?
    var timerLastResumedAt: Date?
    var timerAccumulatedSeconds: Int
    var actualEndedAt: Date?
    var actualDurationSeconds: Int?
    var completionMode: ExerciseCompletionMode?
    var clientUpdatedAt: Date

    init(
        id: UUID = UUID(),
        type: TodayActionType,
        title: String,
        description: String,
        reason: String,
        scheduledStartAt: Date,
        durationMinutes: Int,
        status: TodayActionStatus = .pending,
        completedAt: Date? = nil,
        sortOrder: Int,
        bloodPressureText: String? = nil,
        adviceText: String? = nil,
        exerciseId: String? = nil,
        exerciseScene: String? = nil,
        exerciseEnergy: String? = nil,
        exerciseContexts: [String] = [],
        exerciseMovementAdvice: String? = nil,
        exerciseIntensityAdvice: String? = nil,
        actualStartedAt: Date? = nil,
        timerLastResumedAt: Date? = nil,
        timerAccumulatedSeconds: Int = 0,
        actualEndedAt: Date? = nil,
        actualDurationSeconds: Int? = nil,
        completionMode: ExerciseCompletionMode? = nil,
        clientUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.reason = reason
        self.scheduledStartAt = scheduledStartAt
        self.durationMinutes = durationMinutes
        self.scheduledEndAt = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: scheduledStartAt) ?? scheduledStartAt
        self.status = status
        self.displayStatus = status
        self.completedAt = completedAt
        self.sortOrder = sortOrder
        self.bloodPressureText = bloodPressureText
        self.adviceText = adviceText
        self.exerciseId = exerciseId
        self.exerciseScene = exerciseScene
        self.exerciseEnergy = exerciseEnergy
        self.exerciseContexts = exerciseContexts
        self.exerciseMovementAdvice = exerciseMovementAdvice
        self.exerciseIntensityAdvice = exerciseIntensityAdvice
        self.actualStartedAt = actualStartedAt
        self.timerLastResumedAt = timerLastResumedAt
        self.timerAccumulatedSeconds = timerAccumulatedSeconds
        self.actualEndedAt = actualEndedAt
        self.actualDurationSeconds = actualDurationSeconds
        self.completionMode = completionMode
        self.clientUpdatedAt = clientUpdatedAt
    }

    var startTimeText: String {
        Self.timeFormatter.string(from: scheduledStartAt)
    }

    var endTimeText: String {
        Self.timeFormatter.string(from: scheduledEndAt)
    }

    var timeRangeText: String {
        "\(startTimeText) - \(endTimeText)"
    }

    var timelineSubtitle: String {
        switch type {
        case .walk:
            return "\(startTimeText) | \(durationMinutes) 分钟"
        case .diet:
            return startTimeText
        case .bpRecheck:
            return startTimeText
        case .rest, .hydration, .sleep, .custom:
            return "\(startTimeText) | \(durationMinutes) 分钟"
        }
    }

    var timelineTimeTint: Color {
        switch displayStatus {
        case .completed:
            return DSTheme.Color.success
        case .skipped:
            return DSTheme.Color.textSecondary
        case .pending, .inProgress, .missed:
            return DSTheme.Color.primary
        }
    }

    func timelineArtworkAssetName(for presentationSex: ExercisePresentationSex) -> String? {
        if let exerciseId,
           let assetName = LowBarrierExerciseCatalog.exercise(id: exerciseId)?.assetImageName(for: presentationSex) {
            return assetName
        }

        if type == .custom || isUserDefinedMovement {
            return "ExerciseCustomGeneric"
        }

        if title.contains("早晨血压") {
            return "TodayCardMorningBloodPressure"
        }

        if title.contains("晚间血压") {
            return "TodayCardEveningBloodPressure"
        }

        if title.contains("早餐") {
            return "TodayCardBreakfast"
        }

        if title.contains("午餐") {
            return "TodayCardLunch"
        }

        if title.contains("晚餐") {
            return "TodayCardDinner"
        }

        if title.contains("原地踏步") {
            return "TodayCardJogInPlace"
        }

        if title.contains("慢走") || title.contains("饭后散步") || type == .walk {
            return "TodayCardWalk"
        }

        return nil
    }

    var timelineArtworkAssetName: String? {
        timelineArtworkAssetName(for: .female)
    }

    private var isUserDefinedMovement: Bool {
        guard exerciseId == nil || exerciseId == "custom-adjusted" else { return false }
        guard type == .walk || type == .custom else { return false }
        let knownWalkingTitles = ["慢走", "散步", "踏步", "快走"]
        return !knownWalkingTitles.contains { title.contains($0) }
    }

    var isExerciseAction: Bool {
        type != .diet && type != .bpRecheck
    }

    var isCatalogExercise: Bool {
        guard let exerciseId else { return false }
        return LowBarrierExerciseCatalog.exercise(id: exerciseId) != nil
    }

    func effectiveStatus(now: Date) -> TodayActionStatus {
        if status == .completed || status == .skipped {
            return status
        }

        if status == .inProgress {
            return .inProgress
        }

        if now > scheduledEndAt {
            return .missed
        }

        return .pending
    }

    static func demoItems() -> [TodayActionItem] {
        [
            make(.bpRecheck, title: "早晨血压测量", hour: 7, minute: 0, duration: 8, order: 0),
            make(.diet, title: "早餐建议", hour: 8, minute: 0, duration: 20, order: 1),
            make(.diet, title: "午餐建议", hour: 12, minute: 0, duration: 25, order: 2),
            make(.diet, title: "晚餐建议", hour: 18, minute: 30, duration: 25, order: 3),
            make(.bpRecheck, title: "晚间血压测量", hour: 21, minute: 30, duration: 8, order: 4)
        ]
    }

    static func generatedDemoItems() -> [TodayActionItem] {
        [
            make(.bpRecheck, title: "早晨血压测量", hour: 7, minute: 0, duration: 8, order: 0),
            make(.diet, title: "早餐建议", hour: 8, minute: 0, duration: 20, order: 1),
            make(.walk, title: "饭后散步", hour: 19, minute: 30, duration: 15, order: 2),
            make(.bpRecheck, title: "晚间血压测量", hour: 21, minute: 30, duration: 8, order: 3)
        ]
    }

    static func generatedMovement(
        title: String,
        timeText: String,
        duration: Int,
        order: Int,
        exercise: LowBarrierExercise? = nil,
        scene: String? = nil,
        energy: String? = nil,
        contexts: [String] = []
    ) -> TodayActionItem {
        let parts = timeText.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 15
        let minute = parts.dropFirst().first ?? 30

        var item = make(
            .walk,
            title: title,
            hour: hour,
            minute: minute,
            duration: duration,
            order: order
        )

        if let exercise {
            item.description = exercise.movementAdvice
            item.reason = "根据当前场景、精力和情景状态推荐的低门槛运动。"
            item.exerciseId = exercise.id
            item.exerciseScene = scene ?? exercise.scene.rawValue
            item.exerciseEnergy = energy
            item.exerciseContexts = contexts
            item.exerciseMovementAdvice = exercise.movementAdvice
            item.exerciseIntensityAdvice = exercise.intensityAdvice
            item.clientUpdatedAt = Date()
        }

        return item
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func make(
        _ type: TodayActionType,
        title: String,
        hour: Int,
        minute: Int,
        duration: Int,
        order: Int,
        bloodPressureText: String? = nil,
        adviceText: String? = nil
    ) -> TodayActionItem {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .minute, value: hour * 60 + minute, to: startOfDay) ?? now

        return TodayActionItem(
            type: type,
            title: title,
            description: type.description(durationMinutes: duration),
            reason: type.reason,
            scheduledStartAt: start,
            durationMinutes: duration,
            sortOrder: order,
            bloodPressureText: bloodPressureText,
            adviceText: adviceText
        )
    }
}

enum TodayActionType: String, CaseIterable, Identifiable, Hashable {
    case walk
    case diet
    case bpRecheck
    case rest
    case hydration
    case sleep
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .walk:
            return "步行"
        case .diet:
            return "饮食"
        case .bpRecheck:
            return "复测血压"
        case .rest:
            return "放松"
        case .hydration:
            return "补水"
        case .sleep:
            return "睡眠"
        case .custom:
            return "自定义"
        }
    }

    var systemImage: String {
        switch self {
        case .walk:
            return "figure.walk"
        case .diet:
            return "fork.knife"
        case .bpRecheck:
            return "heart.text.square"
        case .rest:
            return "wind"
        case .hydration:
            return "drop.fill"
        case .sleep:
            return "moon.zzz.fill"
        case .custom:
            return "star.fill"
        }
    }

    var accent: Color {
        switch self {
        case .bpRecheck:
            return Color(red: 0.18, green: 0.38, blue: 0.78)
        case .diet:
            return Color(red: 0.63, green: 0.66, blue: 0.42)
        case .walk:
            return Color(red: 0.14, green: 0.55, blue: 0.32)
        case .rest, .sleep:
            return Color(red: 0.35, green: 0.42, blue: 0.72)
        case .hydration:
            return Color(red: 0.12, green: 0.56, blue: 0.86)
        case .custom:
            return DSTheme.Color.primary
        }
    }

    var reason: String {
        switch self {
        case .walk:
            return "轻量活动有助于形成稳定的日常节奏，也便于观察读数趋势。"
        case .diet:
            return "饮食选择会影响当天身体状态，低盐选项更适合持续记录和观察。"
        case .bpRecheck:
            return "固定时间复测能减少偶然因素，让趋势更容易比较。"
        case .rest:
            return "短时间放松可以帮助降低测量前后的紧张感。"
        case .hydration:
            return "规律补水是简单的日常行动，适合放在时间轴中提醒。"
        case .sleep:
            return "睡前准备有助于维持稳定作息，后续可结合睡眠数据观察。"
        case .custom:
            return "这是用户自行调整的行动。"
        }
    }

    func description(durationMinutes: Int) -> String {
        switch self {
        case .walk:
            return "保持轻量运动 \(durationMinutes) 分钟，不追求强度。"
        case .diet:
            return "选择清淡、少盐、不过量的一餐，完成后点亮行动。"
        case .bpRecheck:
            return "安静坐位休息后复测，记录读数即可。"
        case .rest:
            return "跟随呼吸节奏放松 \(durationMinutes) 分钟。"
        case .hydration:
            return "喝一杯水，完成后点亮今日行动。"
        case .sleep:
            return "减少屏幕刺激，准备进入睡眠。"
        case .custom:
            return "按你调整后的计划完成这个行动。"
        }
    }
}

enum TodayActionStatus: String, Hashable {
    case pending
    case inProgress
    case completed
    case skipped
    case missed

    var title: String {
        switch self {
        case .pending:
            return "未开始"
        case .inProgress:
            return "正在进行"
        case .completed:
            return "已完成"
        case .skipped:
            return "已跳过"
        case .missed:
            return "已错过"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            return "clock"
        case .inProgress:
            return "dot.radiowaves.left.and.right"
        case .completed:
            return "checkmark.circle.fill"
        case .skipped:
            return "forward.fill"
        case .missed:
            return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending:
            return DSTheme.Color.primary
        case .inProgress:
            return Color(red: 1.0, green: 0.55, blue: 0.14)
        case .completed:
            return DSTheme.Color.success
        case .skipped:
            return DSTheme.Color.textSecondary
        case .missed:
            return DSTheme.Color.warning
        }
    }
}

#Preview {
    @Previewable @State var items = TodayActionItem.demoItems()
    TodayActionView(items: $items, userId: "preview-user")
}
