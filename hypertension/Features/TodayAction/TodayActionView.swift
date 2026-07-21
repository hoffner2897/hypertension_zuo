import SwiftUI

struct TodayActionView: View {
    @Binding var items: [TodayActionItem]
    let onOpenBloodPressure: () -> Void

    @State private var path: [TodayActionRoute] = []
    private let statusBarClearance: CGFloat = 54

    private var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    private var remainingCount: Int {
        max(items.count - completedCount, 0)
    }

    private var completionRate: Double {
        guard !items.isEmpty else {
            return 0
        }

        return Double(completedCount) / Double(items.count)
    }

    private var hasMissedItems: Bool {
        items.contains { $0.effectiveStatus(now: Date()) == .missed }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                TreeStageBackground(completionRate: completionRate, hasMissedItems: hasMissedItems)
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
                            onComplete: { updateStatus(.completed, for: id) },
                            onSkip: { updateStatus(.skipped, for: id) },
                            onAdjust: { path.append(.adjust(id)) }
                        )
                    }
                case .adjust(let id):
                    if let item = item(with: id) {
                        TodayActionAdjustView(item: item) { updatedItem in
                            replaceItem(updatedItem)
                            path.removeLast()
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日行动")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))

                Text("Today's Action")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }

            Spacer()

            VStack(spacing: 4) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color(red: 0.18, green: 0.41, blue: 0.92))
                    .background(Circle().fill(.white))

                Text("小宁")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textPrimary)
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: DSTheme.Spacing.small) {
            TodaySummaryCard(
                icon: "checkmark",
                iconColor: Color(red: 0.12, green: 0.38, blue: 0.95),
                title: "已完成",
                value: "\(completedCount)",
                suffix: "项"
            )

            TodaySummaryCard(
                icon: "clock.fill",
                iconColor: Color(red: 1.0, green: 0.56, blue: 0.12),
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

            TodayTreeTimelineView(
                items: displayItems,
                now: now,
                onSelect: { id in
                    path.append(.detail(id))
                }
            )
            .frame(height: timelineHeight(for: displayItems.count))
        }
    }

    private func timelineHeight(for itemCount: Int) -> CGFloat {
        max(920, CGFloat(itemCount + 1) * 178 + 140)
    }

    private func item(with id: UUID) -> TodayActionItem? {
        items.first { $0.id == id }
    }

    private func updateStatus(_ status: TodayActionStatus, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].status = status
        if status == .completed {
            items[index].completedAt = Date()
        }
        path.removeAll()
    }

    private func replaceItem(_ item: TodayActionItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index] = item
    }
}

struct ActionGenerateDemoView: View {
    let onOpenBloodPressure: () -> Void
    let onGenerateAction: (TodayActionItem) -> Void
    @State private var activeSheet: ActionGenerationSheet?
    @State private var scene = "公共室内"
    @State private var energy = "精力一般"
    @State private var contexts: Set<String> = ["饭后"]
    @State private var hasDiscomfort = false
    @State private var currentMovement = "慢走"
    @State private var movementDuration = 15
    @State private var currentTime = "15:30"
    @State private var reminderTimes = ["18:30", "20:00"]
    @State private var usesSystemPreference = true
    @State private var customMovementName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TreeStageBackground(completionRate: 0.35)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("行动生成")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.45))

                                Text("Action Studio")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }

                            Spacer()

                            VStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(DSTheme.Color.primary)

                                Text("小宁")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.textPrimary)
                            }
                        }

                        DSCard(padding: DSTheme.Spacing.small) {
                            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                                HStack(spacing: 8) {
                                    Label("今日血压状态", systemImage: "heart.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DSTheme.Color.textSecondary)

                                    Spacer()

                                    Label("状态正常", systemImage: "checkmark.circle.fill")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(DSTheme.Color.success)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(DSTheme.Color.success.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("128 / 82")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.45))

                                    Text("mmHg")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(DSTheme.Color.textSecondary)
                                }

                                Label("如有头晕、胸闷、心慌或明显不适，请先休息并复测。", systemImage: "shield.checkered")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                                    .lineLimit(2)
                            }
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: DSTheme.Spacing.small),
                                GridItem(.flexible(), spacing: DSTheme.Spacing.small)
                            ],
                            spacing: DSTheme.Spacing.small
                        ) {
                            ActionSetupCard(
                                title: "场景选择",
                                value: scene,
                                systemImage: "mappin.circle.fill",
                                illustration: "laptopcomputer",
                                tint: DSTheme.Color.primary
                            ) {
                                activeSheet = .scene
                            }

                            ActionSetupCard(
                                title: "状态选择",
                                value: "\(energy) · \(contexts.sorted().joined(separator: "、"))",
                                systemImage: "face.smiling.fill",
                                illustration: "person.fill.checkmark",
                                tint: Color(red: 0.15, green: 0.52, blue: 0.35)
                            ) {
                                activeSheet = .status
                            }

                            ActionSetupCard(
                                title: "当前运动选择",
                                value: currentMovement.isEmpty ? "先选择再开始" : currentMovement,
                                systemImage: "figure.walk.circle.fill",
                                illustration: "figure.walk",
                                tint: DSTheme.Color.primary
                            ) {
                                activeSheet = .currentMovement
                            }

                            ActionSetupCard(
                                title: "后续运动时间",
                                value: "\(reminderTimes.count) 个提醒时段",
                                systemImage: "clock.badge.checkmark.fill",
                                illustration: "alarm.fill",
                                tint: Color(red: 0.36, green: 0.49, blue: 0.82)
                            ) {
                                activeSheet = .reminders
                            }
                        }

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
                                    Text("偏好运动设置")
                                        .font(.headline)
                                        .foregroundStyle(DSTheme.Color.textPrimary)

                                    Text("可记录跑步、骑车或健身计划")
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

                        DSPrimaryButton("继续设置") {
                            activeSheet = .scene
                        }

                        DSSecondaryButton("先记录血压", systemImage: "heart.text.square") {
                            onOpenBloodPressure()
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                    .padding(.bottom, 170)
                }
            }
            .navigationTitle("行动生成")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .scene:
                    SceneSelectionSheet(scene: $scene) {
                        activeSheet = nil
                    }
                case .status:
                    StatusSelectionSheet(
                        energy: $energy,
                        contexts: $contexts,
                        hasDiscomfort: $hasDiscomfort
                    ) {
                        activeSheet = nil
                    }
                case .currentMovement:
                    CurrentMovementSheet(
                        scene: scene,
                        stateSummary: stateSummary,
                        movement: $currentMovement,
                        duration: $movementDuration,
                        time: $currentTime
                    ) {
                        generateCurrentMovement()
                        activeSheet = nil
                    }
                case .reminders:
                    ReminderTimeSheet(reminderTimes: $reminderTimes) {
                        generateReminderMovements()
                        activeSheet = nil
                    }
                case .preference:
                    PreferenceMovementSheet(
                        usesSystemPreference: $usesSystemPreference,
                        customMovementName: $customMovementName
                    ) {
                        activeSheet = nil
                    }
                }
            }
        }
    }

    private var stateSummary: String {
        let contextText = contexts.sorted().joined(separator: "、")
        return contextText.isEmpty ? energy : "\(energy) · \(contextText)"
    }

    private var generatedActionTitle: String {
        if contexts.contains("饭后") && currentMovement == "慢走" {
            return "饭后散步"
        }

        return currentMovement
    }

    private func generateCurrentMovement() {
        let item = TodayActionItem.generatedMovement(
            title: generatedActionTitle,
            timeText: currentTime,
            duration: movementDuration,
            order: 99
        )
        onGenerateAction(item)
    }

    private func generateReminderMovements() {
        for (index, timeText) in reminderTimes.enumerated() {
            let item = TodayActionItem.generatedMovement(
                title: "运动提醒",
                timeText: timeText,
                duration: movementDuration,
                order: 100 + index
            )
            onGenerateAction(item)
        }
    }
}

struct ActionAdjustDemoView: View {
    @Binding var items: [TodayActionItem]
    @State private var selectedItem: TodayActionItem?

    var body: some View {
        NavigationStack {
            ZStack {
                TreeStageBackground(completionRate: 0.65)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "行动调整",
                            subtitle: "替换行动、调整时间或时长，保持今日计划适合当下。",
                            systemImage: "slider.horizontal.3"
                        )

                        ForEach(items) { item in
                            DSCard {
                                HStack(spacing: DSTheme.Spacing.medium) {
                                    Image(systemName: item.type.systemImage)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(DSTheme.Color.primary)
                                        .frame(width: 42, height: 42)
                                        .background(DSTheme.Color.primarySoft)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(DSTheme.Color.textPrimary)

                                        Text(item.timeRangeText)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(DSTheme.Color.textSecondary)
                                    }

                                    Spacer()

                                    Button {
                                        selectedItem = item
                                    } label: {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.headline)
                                            .foregroundStyle(DSTheme.Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                    .padding(.bottom, 170)
                }
            }
            .navigationTitle("行动调整")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedItem) { item in
                TodayActionAdjustView(item: item) { updatedItem in
                    if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                        items[index] = updatedItem
                    }
                    selectedItem = nil
                }
            }
        }
    }
}

private enum ActionGenerationSheet: String, Identifiable {
    case scene
    case status
    case currentMovement
    case reminders
    case preference

    var id: String {
        rawValue
    }
}

private struct ActionOption: Identifiable {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var id: String {
        title
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
        ActionOption(title: "私人室内", subtitle: "例如：在家中进行", systemImage: "sofa.fill", tint: Color(red: 0.55, green: 0.62, blue: 0.83)),
        ActionOption(title: "公共室内", subtitle: "例如：在工位或教室", systemImage: "laptopcomputer", tint: DSTheme.Color.primary),
        ActionOption(title: "公共室外", subtitle: "例如：商场、车站、步行街", systemImage: "building.2.fill", tint: Color(red: 0.50, green: 0.70, blue: 0.86)),
        ActionOption(title: "私人/开放室外", subtitle: "例如：公园、广场、景区", systemImage: "tree.fill", tint: Color(red: 0.20, green: 0.58, blue: 0.36))
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
                        if contexts.contains(option.title) {
                            contexts.remove(option.title)
                        } else {
                            contexts.insert(option.title)
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

private struct CurrentMovementSheet: View {
    let scene: String
    let stateSummary: String
    @Binding var movement: String
    @Binding var duration: Int
    @Binding var time: String
    let onConfirm: () -> Void

    private let options = [
        ActionOption(title: "慢走", subtitle: "", systemImage: "figure.walk", tint: DSTheme.Color.primary),
        ActionOption(title: "原地踏步", subtitle: "", systemImage: "figure.highintensity.intervaltraining", tint: Color(red: 0.58, green: 0.35, blue: 0.78)),
        ActionOption(title: "坐站练习", subtitle: "", systemImage: "figure.stand", tint: Color(red: 0.55, green: 0.45, blue: 0.33)),
        ActionOption(title: "靠墙静蹲", subtitle: "", systemImage: "figure.strengthtraining.traditional", tint: Color(red: 0.45, green: 0.54, blue: 0.82))
    ]

    var body: some View {
        SheetContent {
            ActionSheetHeader(title: "当前运动选择", subtitle: "根据已选择场景为您匹配当前运动", onClose: onConfirm)

            VStack(alignment: .leading, spacing: 8) {
                Label("当前位置：\(scene)", systemImage: "mappin.circle.fill")
                Label("当前状态：\(stateSummary)", systemImage: "heart.circle.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DSTheme.Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSTheme.Spacing.medium)
            .background(DSTheme.Color.primarySoft.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            SheetSectionTitle("选择运动类型", systemImage: "figure.walk.circle.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSTheme.Spacing.small) {
                ForEach(options) { option in
                    ActionChoiceTile(
                        title: option.title,
                        subtitle: "",
                        systemImage: option.systemImage,
                        tint: option.tint,
                        isSelected: movement == option.title
                    ) {
                        movement = option.title
                    }
                }
            }

            SheetSectionTitle("选择运动时长", systemImage: "timer")
            HStack(spacing: DSTheme.Spacing.small) {
                ForEach([10, 15, 20, 30], id: \.self) { minutes in
                    Button {
                        duration = minutes
                    } label: {
                        Text("\(minutes) 分钟")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(duration == minutes ? .white : DSTheme.Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(duration == minutes ? DSTheme.Color.primary : DSTheme.Color.primarySoft.opacity(0.65))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            SheetSectionTitle("预约开始时间", systemImage: "clock.fill")
            Menu {
                ForEach(["15:30", "16:00", "16:30", "17:00"], id: \.self) { value in
                    Button(value) {
                        time = value
                    }
                }
            } label: {
                HStack {
                    Label(time, systemImage: "clock")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .font(.headline)
                .foregroundStyle(DSTheme.Color.primary)
                .padding(DSTheme.Spacing.medium)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Label("后续提醒时段将优先避开用餐、复测后再安排运动补充。", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .padding(DSTheme.Spacing.medium)
                .background(DSTheme.Color.primarySoft.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            DSPrimaryButton("确认当前运动", action: onConfirm)
        }
        .presentationDetents([.large])
    }
}

private struct ReminderTimeSheet: View {
    @Binding var reminderTimes: [String]
    let onConfirm: () -> Void

    var body: some View {
        SheetContent {
            ActionSheetHeader(title: "后续运动时间", subtitle: "先设置今天剩余时段，到点后再选择具体运动", onClose: onConfirm)

            VStack(spacing: DSTheme.Spacing.small) {
                ForEach(Array(reminderTimes.enumerated()), id: \.offset) { index, time in
                    HStack(spacing: DSTheme.Spacing.small) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(DSTheme.Color.primary)
                            .frame(width: 34, height: 34)
                            .background(DSTheme.Color.primarySoft)
                            .clipShape(Circle())

                        Text("第 \(index + 1) 个提醒时段")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DSTheme.Color.textPrimary)

                        Spacer()

                        Text(time)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.45))

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DSTheme.Color.textSecondary)
                    }
                    .padding(DSTheme.Spacing.medium)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    guard reminderTimes.count < 3 else { return }
                    reminderTimes.append("21:00")
                } label: {
                    Label("添加提醒时段", systemImage: "plus.circle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(DSTheme.Spacing.medium)
                        .background(.white.opacity(0.68))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DSTheme.Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        }
                }
                .buttonStyle(.plain)
                .disabled(reminderTimes.count >= 3)
            }

            Text("每天最多设置 3 个运动提醒时段。")
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            DSPrimaryButton("确认后续时间", action: onConfirm)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PreferenceMovementSheet: View {
    @Binding var usesSystemPreference: Bool
    @Binding var customMovementName: String
    let onConfirm: () -> Void

    var body: some View {
        SheetContent {
            ActionSheetHeader(title: "偏好运动设置（可选）", subtitle: "记录你已有的运动计划，我们会提供时长和注意事项提醒", onClose: onConfirm)

            VStack(spacing: DSTheme.Spacing.small) {
                PreferenceModeRow(
                    title: "按系统低门槛运动生成",
                    isSelected: usesSystemPreference
                ) {
                    usesSystemPreference = true
                }

                PreferenceModeRow(
                    title: "我已有想做的运动",
                    isSelected: !usesSystemPreference
                ) {
                    usesSystemPreference = false
                }
            }

            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                Text("运动名称")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)

                TextField("例如：骑车", text: $customMovementName)
                    .textInputAutocapitalization(.never)
                    .padding(DSTheme.Spacing.medium)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: DSTheme.Spacing.small) {
                StaticTimeField(title: "开始时间", value: "18:30")
                StaticTimeField(title: "结束时间", value: "19:30")
            }

            Label("系统只提供记录、时长和注意事项提醒，不作为主动推荐。", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .padding(DSTheme.Spacing.medium)
                .background(DSTheme.Color.primarySoft.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            DSPrimaryButton("保存偏好运动", action: onConfirm)
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
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 74)
                        .background(tint.opacity(0.12))
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

private struct PreferenceModeRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTheme.Spacing.small) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DSTheme.Color.primary : DSTheme.Color.textSecondary)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textPrimary)

                Spacer()
            }
            .padding(DSTheme.Spacing.medium)
            .background(isSelected ? DSTheme.Color.primarySoft.opacity(0.72) : .white)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? DSTheme.Color.primary.opacity(0.55) : DSTheme.Color.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StaticTimeField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            HStack {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(DSTheme.Color.textPrimary)

                Spacer()

                Image(systemName: "clock")
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
            .padding(DSTheme.Spacing.medium)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private enum TodayActionRoute: Hashable {
    case detail(UUID)
    case adjust(UUID)
}

private struct TodaySummaryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let suffix: String

    var body: some View {
        HStack(spacing: DSTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(iconColor)
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
    let onSelect: (UUID) -> Void

    private var range: TodayTimelineRange {
        TodayTimelineRange(items: items, now: now)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let axisX = size.width * 0.5
            let topInset: CGFloat = 78
            let bottomInset: CGFloat = 84
            let usableHeight = max(size.height - topInset - bottomInset, 1)
            let lanePadding: CGFloat = 14
            let cardWidth = max((size.width - lanePadding * 2 - 28) / 2, 122)
            let leftCardX = lanePadding + cardWidth / 2
            let rightCardX = size.width - lanePadding - cardWidth / 2
            let sortedItems = items.sorted {
                if $0.scheduledStartAt == $1.scheduledStartAt {
                    return $0.sortOrder < $1.sortOrder
                }

                return $0.scheduledStartAt < $1.scheduledStartAt
            }
            let positions = TimelinePositioner.positions(
                items: sortedItems,
                now: now,
                range: range,
                topInset: topInset,
                usableHeight: usableHeight,
                minimumSpacing: 166
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
                        .frame(width: 5, height: usableHeight)
                        .overlay {
                            Rectangle()
                                .fill(DSTheme.Color.primary.opacity(0.28))
                                .frame(width: 1.5)
                        }
                }
                .position(x: axisX, y: topInset + usableHeight / 2)

                ForEach(sortedItems) { item in
                    let y = positions.itemY[item.id] ?? topInset + usableHeight * range.progress(for: item.scheduledStartAt)
                    let isMeal = item.type == .diet
                    let cardX = isMeal ? rightCardX : leftCardX
                    let cardEdgeX = isMeal ? cardX - cardWidth / 2 + 8 : cardX + cardWidth / 2 - 8
                    let axisEdgeX = isMeal ? axisX + 18 : axisX - 18

                    TimelineConnector(
                        fromX: axisEdgeX,
                        toX: cardEdgeX,
                        y: y,
                        tint: item.type.accent
                    )
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .allowsHitTesting(false)

                    TimeBubble(text: item.startTimeText, tint: item.timelineTimeTint)
                        .position(x: axisX, y: y)

                    DesignActionCard(item: item)
                        .frame(width: cardWidth)
                        .position(x: cardX, y: y)
                        .onTapGesture {
                            onSelect(item.id)
                    }
                }

                CurrentTimeGlow(
                    timeText: TodayActionItem.timeFormatter.string(from: now),
                    tint: Color(red: 1.0, green: 0.55, blue: 0.14)
                )
                .position(x: axisX, y: positions.currentY)
            }
        }
    }
}

private struct TimelinePositioner {
    static func positions(
        items: [TodayActionItem],
        now: Date,
        range: TodayTimelineRange,
        topInset: CGFloat,
        usableHeight: CGFloat,
        minimumSpacing: CGFloat
    ) -> (itemY: [UUID: CGFloat], currentY: CGFloat) {
        var events = items.map { TimelinePositionEvent.item($0.id, $0.scheduledStartAt) }
        events.append(.current(now))
        events.sort { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.sortRank < rhs.sortRank
            }

            return lhs.date < rhs.date
        }

        var resolved: [TimelinePositionEvent: CGFloat] = [:]
        var previousY: CGFloat?

        for event in events {
            let naturalY = topInset + usableHeight * range.progress(for: event.date)
            let y: CGFloat
            if let previousY {
                y = max(naturalY, previousY + minimumSpacing)
            } else {
                y = naturalY
            }

            resolved[event] = y
            previousY = y
        }

        var itemY: [UUID: CGFloat] = [:]
        var currentY = topInset + usableHeight * range.progress(for: now)

        for (event, y) in resolved {
            switch event {
            case .item(let id, _):
                itemY[id] = y
            case .current:
                currentY = y
            }
        }

        return (itemY, currentY)
    }
}

private enum TimelinePositionEvent: Hashable {
    case item(UUID, Date)
    case current(Date)

    var date: Date {
        switch self {
        case .item(_, let date), .current(let date):
            return date
        }
    }

    var sortRank: Int {
        switch self {
        case .item:
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.40))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(item.timelineSubtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.46))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                TimelineActionArtwork(item: item)
                    .frame(width: item.type == .diet ? 58 : 54, height: item.type == .diet ? 54 : 58)
            }

            statusPill

            switch item.type {
            case .bpRecheck:
                metricPill(item.bloodPressureText ?? "128/82", suffix: "mmHg")
            case .diet:
                adviceBox
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
        .frame(maxWidth: .infinity, minHeight: item.type == .diet ? 158 : 116, alignment: .topLeading)
        .background(.white.opacity(0.93))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var statusPill: some View {
        Text(item.displayStatus.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(item.displayStatus.tint.opacity(0.18))
            .clipShape(Capsule())
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
}

private struct TimelineActionArtwork: View {
    let item: TodayActionItem

    var body: some View {
        if let assetName = item.timelineArtworkAssetName {
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
    var hasMissedItems = false

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
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

    private var assetName: String {
        if hasMissedItems {
            switch completionRate {
            case ..<0.33:
                return "TreeIncomplete0_33"
            case ..<0.67:
                return "TreeIncomplete33_67"
            default:
                return "TreeIncomplete67_100"
            }
        }

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

private struct TodayActionDetailView: View {
    let item: TodayActionItem
    let effectiveStatus: TodayActionStatus
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onAdjust: () -> Void

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

                            Text(item.description)
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

                        DSSecondaryButton("调整行动", systemImage: "slider.horizontal.3") {
                            onAdjust()
                        }

                        DSSecondaryButton("跳过今天", systemImage: "forward.fill", isDisabled: item.status == .completed) {
                            onSkip()
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
}

private struct TodayActionAdjustView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TodayActionItem

    let onSave: (TodayActionItem) -> Void

    init(item: TodayActionItem, onSave: @escaping (TodayActionItem) -> Void) {
        _draft = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TreeStageBackground(completionRate: 0.55)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader("调整行动", subtitle: "修改标题、时间、时长或类型。", systemImage: "slider.horizontal.3")

                        DSCard {
                            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                                TextField("行动标题", text: $draft.title)
                                    .font(.body.weight(.semibold))
                                    .textFieldStyle(.roundedBorder)

                                Stepper(value: $draft.durationMinutes, in: 5...90, step: 5) {
                                    Text("时长 \(draft.durationMinutes) 分钟")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(DSTheme.Color.textPrimary)
                                }

                                DatePicker("开始时间", selection: $draft.scheduledStartAt, displayedComponents: [.hourAndMinute])
                                    .font(.subheadline.weight(.semibold))

                                Picker("行动类型", selection: $draft.type) {
                                    ForEach(TodayActionType.allCases) { type in
                                        Label(type.title, systemImage: type.systemImage).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        DSPrimaryButton("保存调整", systemImage: "checkmark.circle.fill") {
                            draft.scheduledEndAt = Calendar.current.date(byAdding: .minute, value: draft.durationMinutes, to: draft.scheduledStartAt) ?? draft.scheduledStartAt
                            onSave(draft)
                        }

                        DSSecondaryButton("取消", systemImage: "xmark.circle") {
                            dismiss()
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                    .padding(.bottom, 130)
                }
            }
            .navigationTitle("调整")
            .navigationBarTitleDisplayMode(.inline)
        }
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
        adviceText: String? = nil
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
    }

    var startTimeText: String {
        Self.timeFormatter.string(from: scheduledStartAt)
    }

    var timeRangeText: String {
        "\(Self.timeFormatter.string(from: scheduledStartAt)) - \(Self.timeFormatter.string(from: scheduledEndAt))"
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

    var timelineArtworkAssetName: String? {
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

    func effectiveStatus(now: Date) -> TodayActionStatus {
        if status == .completed || status == .skipped {
            return status
        }

        if now >= scheduledStartAt && now <= scheduledEndAt {
            return .inProgress
        }

        if now > scheduledEndAt {
            return .missed
        }

        return .pending
    }

    static func demoItems() -> [TodayActionItem] {
        [
            make(.bpRecheck, title: "早晨血压测量", hour: 7, minute: 45, duration: 8, order: 0, bloodPressureText: "128/82"),
            make(.diet, title: "早餐建议", hour: 8, minute: 0, duration: 20, order: 1, adviceText: "白米饭和鸡蛋较清淡，建议后续搭配蔬菜或水果，更利于控压。"),
            make(.diet, title: "午餐建议", hour: 12, minute: 0, duration: 25, order: 2, adviceText: "咖喱鸡米饭较均衡，建议少盐少油，并搭配更多蔬菜或杂粮饭。"),
            make(.diet, title: "晚餐建议", hour: 18, minute: 30, duration: 25, order: 3, adviceText: "猪肉末彩椒碗有蛋白质和蔬菜，建议少盐少油；下次类似食材可搭配瘦肉、彩椒和杂粮饭。"),
            make(.bpRecheck, title: "晚间血压测量", hour: 21, minute: 30, duration: 8, order: 4, bloodPressureText: "128/82")
        ]
    }

    static func generatedDemoItems() -> [TodayActionItem] {
        [
            make(.bpRecheck, title: "早晨血压测量", hour: 7, minute: 45, duration: 8, order: 0, bloodPressureText: "128/82"),
            make(.diet, title: "早餐建议", hour: 8, minute: 0, duration: 20, order: 1, adviceText: "白米饭和鸡蛋较清淡，建议后续搭配蔬菜或水果，更利于控压。"),
            make(.walk, title: "饭后散步", hour: 19, minute: 30, duration: 15, order: 2),
            make(.bpRecheck, title: "晚间血压测量", hour: 21, minute: 30, duration: 8, order: 3, bloodPressureText: "128/82")
        ]
    }

    static func generatedMovement(
        title: String,
        timeText: String,
        duration: Int,
        order: Int
    ) -> TodayActionItem {
        let parts = timeText.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 15
        let minute = parts.dropFirst().first ?? 30

        return make(
            .walk,
            title: title,
            hour: hour,
            minute: minute,
            duration: duration,
            order: order
        )
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
            return "保持轻松步行 \(durationMinutes) 分钟，不追求强度。"
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
    TodayActionView(items: $items, onOpenBloodPressure: {})
}
