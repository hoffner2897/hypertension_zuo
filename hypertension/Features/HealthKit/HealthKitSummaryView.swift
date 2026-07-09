import Combine
import SwiftUI

struct HealthKitSummaryView: View {
    @StateObject private var viewModel = HealthKitSummaryViewModel()
    @State private var isEditingData = false
    @State private var selectedField: HealthDataField?

    var body: some View {
        NavigationStack {
            SyncedHealthDataContent(
                viewModel: viewModel,
                primaryTitle: viewModel.primaryActionTitle,
                primaryIcon: viewModel.primaryActionIcon,
                isPrimaryDisabled: false,
                onPrimary: {
                    Task {
                        await viewModel.primaryAction()
                    }
                },
                secondaryTitle: "手动补充",
                secondaryIcon: "square.and.pencil",
                onSecondary: {
                    isEditingData = true
                },
                onSelectCard: { field in
                    selectedField = field
                }
            )
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await viewModel.primaryAction()
                        }
                    } label: {
                        Image(systemName: viewModel.primaryActionIcon)
                    }
                    .accessibilityLabel(viewModel.primaryActionTitle)
                    .disabled(viewModel.isLoading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingData = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("手动补充基础数据")
                }
            }
            .task {
                await viewModel.refresh()
            }
            .sheet(isPresented: $isEditingData) {
                HealthDataEditorView(draft: viewModel.makeDraft()) { draft in
                    Task {
                        if await viewModel.saveManualData(draft) {
                            isEditingData = false
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedField) { field in
                HealthDataEditorView(draft: viewModel.makeDraft(), highlightedField: field) { draft in
                    Task {
                        if await viewModel.saveManualData(draft) {
                            selectedField = nil
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
    }
}

struct SyncedHealthDataContent: View {
    @ObservedObject var viewModel: HealthKitSummaryViewModel
    let primaryTitle: String
    let primaryIcon: String
    let isPrimaryDisabled: Bool
    let onPrimary: () -> Void
    let secondaryTitle: String
    let secondaryIcon: String
    let onSecondary: () -> Void
    var onSelectCard: (HealthDataField) -> Void = { _ in }
    var isEmbedded = false

    var body: some View {
        if isEmbedded {
            content
        } else {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    content
                        .padding(DSTheme.Spacing.large)
                        .padding(.bottom, 112)
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
            header
            statusCard

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.cards) { card in
                    SyncedHealthDataCard(card: card) {
                        onSelectCard(card.id)
                    }
                }
            }

            Text("数据来源：\(viewModel.dataSourceText)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            DSCard {
                HStack(spacing: DSTheme.Spacing.medium) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DSTheme.Color.primary)

                    Text("这些数据将用于后续理解血压读数，不用于诊断。点击重新同步会用 Apple Health 当前可读取的数据更新；Apple Health 缺失的项目会保留手动补充值。")
                        .font(.subheadline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                AuthErrorBanner(message: errorMessage)
            }

            VStack(spacing: DSTheme.Spacing.small) {
                DSPrimaryButton(primaryTitle, systemImage: primaryIcon, isLoading: viewModel.isLoading, isDisabled: isPrimaryDisabled) {
                    onPrimary()
                }

                DSSecondaryButton(secondaryTitle, systemImage: secondaryIcon, isDisabled: viewModel.isLoading) {
                    onSecondary()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
            Text("已同步基础数据")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DSTheme.Color.primary)

            Text("这些信息已从 Apple Health 和 Apple Watch 自动获取，也可以手动补充。")
                .font(.subheadline)
                .foregroundStyle(DSTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        DSCard {
            HStack(alignment: .top, spacing: DSTheme.Spacing.medium) {
                Image(systemName: viewModel.statusIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 44, height: 44)
                    .background(DSTheme.Color.primarySoft)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                    Text(viewModel.statusTitle)
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Text(viewModel.statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(viewModel.lastSyncText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
}

struct SyncedHealthCardModel: Identifiable {
    let id: HealthDataField
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let source: HealthDataValueSource
}

enum HealthDataValueSource {
    case health
    case manual
    case missing
}

enum HealthDataField: String, CaseIterable, Identifiable {
    case birthYear
    case sex
    case heightCm
    case weightKg
    case todaySteps
    case exerciseMinutes
    case restingHeartRate
    case sleepHours

    var id: String { rawValue }
}

private struct SyncedHealthDataCard: View {
    let card: SyncedHealthCardModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                HStack(spacing: DSTheme.Spacing.small) {
                    Image(systemName: card.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 44, height: 44)
                        .background(iconColor.opacity(0.12))
                        .clipShape(Circle())

                    Spacer(minLength: 0)

                    Image(systemName: "square.and.pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(card.value)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(DSTheme.Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        if !card.unit.isEmpty {
                            Text(card.unit)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        }
                    }
                }
            }
            .padding(DSTheme.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(DSTheme.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                    .stroke(DSTheme.Color.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch card.source {
        case .health, .manual:
            DSTheme.Color.primary
        case .missing:
            DSTheme.Color.textSecondary
        }
    }
}

struct HealthDataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HealthProfileDraft
    @FocusState private var focusedField: HealthDataField?
    let highlightedField: HealthDataField?
    let onSave: (HealthProfileDraft) -> Void

    init(draft: HealthProfileDraft, highlightedField: HealthDataField? = nil, onSave: @escaping (HealthProfileDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.highlightedField = highlightedField
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "补充基础数据",
                            subtitle: "Apple Health 缺失或不准确时，可以手动维护这些背景信息。",
                            systemImage: "square.and.pencil"
                        )

                        VStack(spacing: DSTheme.Spacing.small) {
                            HealthDataEditorInputRow(title: "出生年份", text: $draft.birthYear, field: .birthYear, focusedField: $focusedField, unit: "年", systemImage: "person.crop.circle", placeholder: "必填")
                                .healthFieldHighlight(highlightedField == .birthYear)

                            Picker("性别", selection: $draft.sex) {
                                Text(verbatim: "女").tag("female")
                                Text(verbatim: "男").tag("male")
                                Text(verbatim: "其他").tag("other")
                                Text(verbatim: "不说明").tag("prefer_not_to_say")
                            }
                            .pickerStyle(.segmented)
                            .padding(8)
                            .background(highlightedField == .sex ? DSTheme.Color.primarySoft : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))

                            HealthDataEditorInputRow(title: "身高", text: $draft.heightCm, field: .heightCm, focusedField: $focusedField, unit: "cm", systemImage: "ruler", placeholder: "可补充")
                                .healthFieldHighlight(highlightedField == .heightCm)
                            HealthDataEditorInputRow(title: "体重", text: $draft.weightKg, field: .weightKg, focusedField: $focusedField, unit: "kg", systemImage: "scalemass", placeholder: "可补充", keyboardType: .decimalPad)
                                .healthFieldHighlight(highlightedField == .weightKg)
                            HealthDataEditorInputRow(title: "今日步数", text: $draft.todaySteps, field: .todaySteps, focusedField: $focusedField, unit: "步", systemImage: "shoeprints.fill", placeholder: "可补充")
                                .healthFieldHighlight(highlightedField == .todaySteps)
                            HealthDataEditorInputRow(title: "运动", text: $draft.exerciseMinutes, field: .exerciseMinutes, focusedField: $focusedField, unit: "分钟", systemImage: "figure.run", placeholder: "可补充")
                                .healthFieldHighlight(highlightedField == .exerciseMinutes)
                            HealthDataEditorInputRow(title: "静息心率", text: $draft.restingHeartRate, field: .restingHeartRate, focusedField: $focusedField, unit: "bpm", systemImage: "waveform.path.ecg", placeholder: "可补充")
                                .healthFieldHighlight(highlightedField == .restingHeartRate)
                            HealthDataEditorInputRow(title: "睡眠", text: $draft.sleepHours, field: .sleepHours, focusedField: $focusedField, unit: "小时", systemImage: "moon.zzz.fill", placeholder: "可补充", keyboardType: .decimalPad)
                                .healthFieldHighlight(highlightedField == .sleepHours)
                        }

                        HStack(spacing: DSTheme.Spacing.small) {
                            DSSecondaryButton("取消", systemImage: "xmark") {
                                dismiss()
                            }

                            DSPrimaryButton("保存", systemImage: "checkmark") {
                                onSave(draft)
                            }
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle("基础数据")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard highlightedField != .sex else {
                    return
                }

                focusedField = highlightedField
            }
        }
    }
}

private struct HealthDataEditorInputRow: View {
    let title: String
    @Binding var text: String
    let field: HealthDataField
    var focusedField: FocusState<HealthDataField?>.Binding
    let unit: String?
    let systemImage: String?
    let placeholder: String
    let keyboardType: UIKeyboardType

    init(
        title: String,
        text: Binding<String>,
        field: HealthDataField,
        focusedField: FocusState<HealthDataField?>.Binding,
        unit: String? = nil,
        systemImage: String? = nil,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .numberPad
    ) {
        self.title = title
        self._text = text
        self.field = field
        self.focusedField = focusedField
        self.unit = unit
        self.systemImage = systemImage
        self.placeholder = placeholder
        self.keyboardType = keyboardType
    }

    var body: some View {
        HStack(spacing: DSTheme.Spacing.medium) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 32, height: 32)
                    .background(DSTheme.Color.primarySoft)
                    .clipShape(Circle())
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)

            Spacer(minLength: DSTheme.Spacing.small)

            TextField(placeholder, text: $text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .focused(focusedField, equals: field)
                .frame(minWidth: 88, maxWidth: 120)

            if let unit {
                Text(unit)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
        .padding(.horizontal, DSTheme.Spacing.medium)
        .frame(minHeight: 58)
        .background(DSTheme.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                .stroke(DSTheme.Color.border, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField.wrappedValue = field
        }
    }
}

private extension View {
    func healthFieldHighlight(_ isHighlighted: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                .stroke(isHighlighted ? DSTheme.Color.primary : Color.clear, lineWidth: 2)
        }
    }
}

struct HealthProfileDraft {
    var birthYear: String
    var sex: String
    var heightCm: String
    var weightKg: String
    var todaySteps: String
    var exerciseMinutes: String
    var restingHeartRate: String
    var sleepHours: String
}

@MainActor
final class HealthKitSummaryViewModel: ObservableObject {
    @Published private(set) var summary = HealthKitSummary(authorizationStatus: .notDetermined)
    @Published private(set) var isLoading = false
    @Published private(set) var profile: UserProfile?
    @Published var errorMessage: String?

    private let healthKitService = HealthKitService()
    private let profileService = ProfileService()

    var statusTitle: String {
        switch summary.authorizationStatus {
        case .unavailable:
            "Apple Health 不可用"
        case .notDetermined:
            "等待授权"
        case .sharingDenied:
            "未获得读取权限"
        case .sharingAuthorized:
            "已连接 Apple Health"
        }
    }

    var statusSubtitle: String {
        switch summary.authorizationStatus {
        case .unavailable:
            "当前设备不支持 HealthKit，仍可手动维护基础数据。"
        case .notDetermined:
            "授权后，BPHealth 会读取年龄、性别、身高、体重、步数、运动、心率和睡眠。"
        case .sharingDenied:
            "请在系统健康权限设置中允许读取，或手动补充缺失数据。"
        case .sharingAuthorized:
            "已读取可用数据，缺失项目可以手动补充。"
        }
    }

    var lastSyncText: String {
        guard let syncedDate = profile.flatMap(Self.syncedDate(from:)) else {
            return "最近同步：尚未完成 Apple Health 同步"
        }

        return "最近同步：\(Self.relativeSyncFormatter.localizedString(for: syncedDate, relativeTo: Date()))"
    }

    var statusIcon: String {
        switch summary.authorizationStatus {
        case .unavailable:
            "exclamationmark.triangle.fill"
        case .notDetermined:
            "heart.text.square"
        case .sharingDenied:
            "lock.fill"
        case .sharingAuthorized:
            "checkmark.seal.fill"
        }
    }

    var primaryActionTitle: String {
        switch summary.authorizationStatus {
        case .sharingAuthorized:
            "重新同步"
        default:
            "连接 Apple Health"
        }
    }

    var primaryActionIcon: String {
        switch summary.authorizationStatus {
        case .sharingAuthorized:
            "arrow.clockwise"
        default:
            "link"
        }
    }

    var dataSourceText: String {
        if hasManualProfileData {
            if hasHealthData {
                return "Apple Health / Apple Watch + 手动补充"
            }

            return "手动输入"
        }

        if hasHealthData {
            return "Apple Health / Apple Watch"
        }

        return profile?.healthDataSource ?? "手动输入"
    }

    var cards: [SyncedHealthCardModel] {
        [
            SyncedHealthCardModel(id: .birthYear, title: "年龄", value: ageText, unit: "岁", systemImage: "person.crop.circle", source: source(profile?.birthYear, summary.birthYear)),
            SyncedHealthCardModel(id: .sex, title: "性别", value: sexText, unit: "", systemImage: "figure.stand", source: source(profile?.sex, summary.biologicalSex)),
            SyncedHealthCardModel(id: .heightCm, title: "身高", value: format(resolvedHeightCm, decimals: 0), unit: "cm", systemImage: "ruler", source: source(profile?.heightCm, summary.latestHeightCm)),
            SyncedHealthCardModel(id: .weightKg, title: "体重", value: format(resolvedWeightKg, decimals: 1), unit: "kg", systemImage: "scalemass", source: source(profile?.weightKg, summary.latestBodyMassKg)),
            SyncedHealthCardModel(id: .todaySteps, title: "今日步数", value: format(resolvedSteps.map(Double.init), decimals: 0), unit: "", systemImage: "shoeprints.fill", source: source(profile?.todaySteps.map(Double.init), summary.todaySteps)),
            SyncedHealthCardModel(id: .exerciseMinutes, title: "运动", value: format(resolvedExerciseMinutes.map(Double.init), decimals: 0), unit: "分钟", systemImage: "figure.run", source: source(profile?.exerciseMinutes.map(Double.init), summary.todayExerciseMinutes)),
            SyncedHealthCardModel(id: .restingHeartRate, title: "静息心率", value: format(resolvedRestingHeartRate.map(Double.init), decimals: 0), unit: "bpm", systemImage: "waveform.path.ecg", source: source(profile?.restingHeartRate.map(Double.init), summary.latestRestingHeartRate)),
            SyncedHealthCardModel(id: .sleepHours, title: "睡眠", value: format(resolvedSleepHours, decimals: 1), unit: "小时", systemImage: "moon.zzz.fill", source: source(profile?.sleepHours, summary.recentSleep.first?.hours))
        ]
    }

    var hasRequiredData: Bool {
        resolvedBirthYear != nil &&
            resolvedSex != nil &&
            resolvedHeightCm != nil &&
            resolvedWeightKg != nil &&
            resolvedSteps != nil &&
            resolvedExerciseMinutes != nil &&
            resolvedRestingHeartRate != nil &&
            resolvedSleepHours != nil
    }

    var missingDataText: String {
        let missing = cards.filter { $0.source == .missing }.map(\.title)
        guard !missing.isEmpty else {
            return ""
        }
        return "请先补充：\(missing.joined(separator: "、"))。"
    }

    func primaryAction() async {
        switch summary.authorizationStatus {
        case .sharingAuthorized:
            await syncFromAppleHealth()
        default:
            await requestAuthorization()
        }
    }

    func requestAuthorization() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await healthKitService.requestAuthorization()
            summary.authorizationStatus = state
            summary = try await healthKitService.fetchSummary()
            try await loadProfile()
            await saveHealthSyncedProfile()
            errorMessage = nil
        } catch {
            errorMessage = "Apple Health 授权或读取失败，可以先手动补充。"
        }
    }

    func syncFromAppleHealth() async {
        isLoading = true
        defer { isLoading = false }

        do {
            summary = try await healthKitService.fetchSummary()
            try await loadProfile()
            _ = await saveHealthSyncedProfile()
            errorMessage = nil
        } catch {
            try? await loadProfile()
            errorMessage = "重新同步 Apple Health 失败，可以使用已保存或手动补充的数据。"
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            summary = try await healthKitService.fetchSummary()
            try await loadProfile()
            errorMessage = nil
        } catch {
            try? await loadProfile()
            errorMessage = "读取 Apple Health 数据失败，可以使用已保存或手动补充的数据。"
        }
    }

    func makeDraft() -> HealthProfileDraft {
        HealthProfileDraft(
            birthYear: resolvedBirthYear.map(String.init) ?? "",
            sex: resolvedSex ?? "prefer_not_to_say",
            heightCm: text(resolvedHeightCm, decimals: 0),
            weightKg: text(resolvedWeightKg, decimals: 1),
            todaySteps: resolvedSteps.map(String.init) ?? "",
            exerciseMinutes: resolvedExerciseMinutes.map(String.init) ?? "",
            restingHeartRate: resolvedRestingHeartRate.map(String.init) ?? "",
            sleepHours: text(resolvedSleepHours, decimals: 1)
        )
    }

    @discardableResult
    func saveManualData(_ draft: HealthProfileDraft) async -> Bool {
        guard let currentProfile = profile else {
            errorMessage = "请先完成 Profile，再保存基础数据。"
            return false
        }

        guard draft.birthYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || optionalIntValue(draft.birthYear, min: 1900, max: Calendar.current.component(.year, from: Date())) != nil else {
            errorMessage = "请输入有效出生年份。"
            return false
        }

        let birthYear = optionalIntValue(draft.birthYear, min: 1900, max: Calendar.current.component(.year, from: Date())) ?? currentProfile.birthYear
        let heightCm = optionalDoubleValue(draft.heightCm, min: 50, max: 260)
        let weightKg = optionalDoubleValue(draft.weightKg, min: 1, max: 500)
        let todaySteps = optionalIntValue(draft.todaySteps, min: 0, max: 200000)
        let exerciseMinutes = optionalIntValue(draft.exerciseMinutes, min: 0, max: 1440)
        let restingHeartRate = optionalIntValue(draft.restingHeartRate, min: 20, max: 240)
        let sleepHours = optionalDoubleValue(draft.sleepHours, min: 0, max: 24)

        if hasInvalidDouble(draft.heightCm, min: 50, max: 260) ||
            hasInvalidDouble(draft.weightKg, min: 1, max: 500) ||
            hasInvalidInt(draft.todaySteps, min: 0, max: 200000) ||
            hasInvalidInt(draft.exerciseMinutes, min: 0, max: 1440) ||
            hasInvalidInt(draft.restingHeartRate, min: 20, max: 240) ||
            hasInvalidDouble(draft.sleepHours, min: 0, max: 24) {
            errorMessage = "请检查基础数据格式和范围。"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await profileService.saveProfile(
                displayName: currentProfile.displayName,
                birthYear: birthYear,
                sex: draft.sex,
                heightCm: heightCm,
                weightKg: weightKg,
                todaySteps: todaySteps,
                exerciseMinutes: exerciseMinutes,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                healthDataSource: hasHealthData ? "Apple Health / Apple Watch + 手动补充" : "手动输入",
                healthDataSyncedAt: Date()
            )
            profile = response.profile
            errorMessage = nil
            return true
        } catch {
            errorMessage = "基础数据保存失败，请稍后重试。"
            return false
        }
    }

    func completeSyncedData() async -> Bool {
        if !hasRequiredData {
            errorMessage = missingDataText
            return false
        }

        return await saveResolvedProfile(source: dataSourceText)
    }

    @discardableResult
    private func saveResolvedProfile(source: String) async -> Bool {
        guard let currentProfile = profile else {
            return false
        }

        guard
            let birthYear = resolvedBirthYear,
            let sex = resolvedSex
        else {
            return false
        }

        do {
            let response = try await profileService.saveProfile(
                displayName: currentProfile.displayName,
                birthYear: birthYear,
                sex: sex,
                heightCm: resolvedHeightCm,
                weightKg: resolvedWeightKg,
                todaySteps: resolvedSteps,
                exerciseMinutes: resolvedExerciseMinutes,
                restingHeartRate: resolvedRestingHeartRate,
                sleepHours: resolvedSleepHours,
                healthDataSource: source,
                healthDataSyncedAt: Date()
            )
            profile = response.profile
            errorMessage = nil
            return true
        } catch {
            errorMessage = "基础数据保存失败，请稍后重试。"
            return false
        }
    }

    private func loadProfile() async throws {
        profile = try await profileService.fetchProfile().profile
    }

    @discardableResult
    private func saveHealthSyncedProfile() async -> Bool {
        guard let currentProfile = profile else {
            return false
        }

        let birthYear = summary.birthYear ?? currentProfile.birthYear
        let sex = summary.biologicalSex ?? currentProfile.sex

        do {
            let response = try await profileService.saveProfile(
                displayName: currentProfile.displayName,
                birthYear: birthYear,
                sex: sex,
                heightCm: summary.latestHeightCm ?? currentProfile.heightCm,
                weightKg: summary.latestBodyMassKg ?? currentProfile.weightKg,
                todaySteps: intFrom(summary.todaySteps) ?? currentProfile.todaySteps,
                exerciseMinutes: intFrom(summary.todayExerciseMinutes) ?? currentProfile.exerciseMinutes,
                restingHeartRate: intFrom(summary.latestRestingHeartRate) ?? currentProfile.restingHeartRate,
                sleepHours: summary.recentSleep.first?.hours ?? currentProfile.sleepHours,
                healthDataSource: hasHealthData ? "Apple Health / Apple Watch" : currentProfile.healthDataSource,
                healthDataSyncedAt: Date()
            )
            profile = response.profile
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Apple Health 同步保存失败，请稍后重试。"
            return false
        }
    }

    private var resolvedBirthYear: Int? {
        profile?.birthYear ?? summary.birthYear
    }

    private var resolvedSex: String? {
        let value = profile?.sex ?? summary.biologicalSex
        return value == "prefer_not_to_say" ? nil : value
    }

    private var resolvedHeightCm: Double? {
        profile?.heightCm ?? summary.latestHeightCm
    }

    private var resolvedWeightKg: Double? {
        profile?.weightKg ?? summary.latestBodyMassKg
    }

    private var resolvedSteps: Int? {
        profile?.todaySteps ?? intFrom(summary.todaySteps)
    }

    private var resolvedExerciseMinutes: Int? {
        profile?.exerciseMinutes ?? intFrom(summary.todayExerciseMinutes)
    }

    private var resolvedRestingHeartRate: Int? {
        profile?.restingHeartRate ?? intFrom(summary.latestRestingHeartRate)
    }

    private var resolvedSleepHours: Double? {
        profile?.sleepHours ?? summary.recentSleep.first?.hours
    }

    private var hasHealthData: Bool {
        summary.birthYear != nil ||
            summary.biologicalSex != nil ||
            summary.latestHeightCm != nil ||
            summary.latestBodyMassKg != nil ||
            summary.todaySteps != nil ||
            summary.todayExerciseMinutes != nil ||
            summary.latestRestingHeartRate != nil ||
            summary.recentSleep.first?.hours != nil
    }

    private var hasManualProfileData: Bool {
        profile?.heightCm != nil ||
            profile?.weightKg != nil ||
            profile?.todaySteps != nil ||
            profile?.exerciseMinutes != nil ||
            profile?.restingHeartRate != nil ||
            profile?.sleepHours != nil
    }

    private var ageText: String {
        guard let birthYear = resolvedBirthYear else {
            return "--"
        }
        return String(max(Calendar.current.component(.year, from: Date()) - birthYear, 0))
    }

    private var sexText: String {
        switch resolvedSex {
        case "female":
            return "女"
        case "male":
            return "男"
        case "other":
            return "其他"
        default:
            return "--"
        }
    }

    private func source<T>(_ manualValue: T?, _ healthValue: T?) -> HealthDataValueSource {
        if manualValue != nil {
            return .manual
        }

        if healthValue != nil {
            return .health
        }

        return .missing
    }

    private static func syncedDate(from profile: UserProfile) -> Date? {
        guard let value = profile.healthDataSyncedAt else {
            return nil
        }

        return isoFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let relativeSyncFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.unitsStyle = .full
        return formatter
    }()

    private func intFrom(_ value: Double?) -> Int? {
        value.map { Int($0.rounded()) }
    }

    private func format(_ value: Double?, decimals: Int) -> String {
        guard let value else {
            return "--"
        }
        return String(format: "%.\(decimals)f", value)
    }

    private func text(_ value: Double?, decimals: Int) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.\(decimals)f", value)
    }

    private func intValue(_ text: String, min: Int, max: Int) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), value >= min, value <= max else {
            return nil
        }
        return value
    }

    private func doubleValue(_ text: String, min: Double, max: Double) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value >= min, value <= max else {
            return nil
        }
        return value
    }

    private func optionalIntValue(_ text: String, min: Int, max: Int) -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        return intValue(trimmedText, min: min, max: max)
    }

    private func optionalDoubleValue(_ text: String, min: Double, max: Double) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        return doubleValue(trimmedText, min: min, max: max)
    }

    private func hasInvalidInt(_ text: String, min: Int, max: Int) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        return intValue(trimmedText, min: min, max: max) == nil
    }

    private func hasInvalidDouble(_ text: String, min: Double, max: Double) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        return doubleValue(trimmedText, min: min, max: max) == nil
    }
}

#Preview {
    HealthKitSummaryView()
}
