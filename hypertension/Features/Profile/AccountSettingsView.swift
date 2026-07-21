import SwiftUI
import SwiftData

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @StateObject private var healthViewModel = HealthKitSummaryViewModel()
    @State private var profile: UserProfile?
    @State private var showDeleteConfirmation = false
    @State private var showEditProfile = false
    @State private var deletePassword = ""
    @State private var isDeleting = false
    @State private var isLoadingProfile = false
    @State private var isEditingHealthData = false
    @State private var selectedHealthField: HealthDataField?

    private let profileService = ProfileService()

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "账号",
                            subtitle: "管理登录状态和账号数据。",
                            systemImage: "person.crop.circle"
                        )

                        DSCard {
                            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                                Text(appState.currentEmail)
                                    .font(.headline)
                                    .foregroundStyle(DSTheme.Color.textPrimary)

                                Text("已登录。血压读数会在后续同步到你的账号。")
                                    .font(.subheadline)
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                                HStack {
                                    Text("Profile")
                                        .font(.headline)
                                        .foregroundStyle(DSTheme.Color.textPrimary)

                                    Spacer()

                                    Button {
                                        showEditProfile = true
                                    } label: {
                                        Image(systemName: "square.and.pencil")
                                            .font(.headline)
                                            .foregroundStyle(DSTheme.Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("编辑 Profile")
                                }

                                if isLoadingProfile {
                                    ProgressView()
                                } else if let profile {
                                    ProfileSummaryRow(title: "昵称", value: profile.displayName)
                                    ProfileSummaryRow(title: "出生年份", value: "\(profile.birthYear)")
                                    ProfileSummaryRow(title: "性别", value: displaySex(profile.sex))
                                } else {
                                    Text("暂时没有读取到 Profile。")
                                        .font(.subheadline)
                                        .foregroundStyle(DSTheme.Color.textSecondary)
                                }
                            }
                        }

                        healthSection

                        DSSecondaryButton("退出登录", systemImage: "rectangle.portrait.and.arrow.right") {
                            Task {
                                await appState.logout()
                            }
                        }

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: DSTheme.Spacing.small) {
                                Image(systemName: "trash.fill")
                                Text("删除账号")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle("账号与健康")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDeleteConfirmation) {
                deleteAccountSheet
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(profile: profile) { updatedProfile in
                    profile = updatedProfile
                    appState.completeProfile(updatedProfile)
                }
            }
            .sheet(isPresented: $isEditingHealthData) {
                HealthDataEditorView(draft: healthViewModel.makeDraft()) { draft in
                    Task {
                        if await healthViewModel.saveManualData(draft) {
                            isEditingHealthData = false
                            await loadProfile()
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedHealthField) { field in
                HealthDataEditorView(draft: healthViewModel.makeDraft(), highlightedField: field) { draft in
                    Task {
                        if await healthViewModel.saveManualData(draft) {
                            selectedHealthField = nil
                            await loadProfile()
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .task {
                await loadProfile()
                await healthViewModel.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await healthViewModel.refresh()
                    await loadProfile()
                }
            }
        }
    }

    private var healthSection: some View {
        SyncedHealthDataContent(
            viewModel: healthViewModel,
            primaryTitle: healthViewModel.primaryActionTitle,
            primaryIcon: healthViewModel.primaryActionIcon,
            isPrimaryDisabled: healthViewModel.isPrimaryActionDisabled,
            onPrimary: {
                Task {
                    await healthViewModel.primaryAction()
                    await loadProfile()
                }
            },
            secondaryTitle: "手动补充",
            secondaryIcon: "square.and.pencil",
            onSecondary: {
                isEditingHealthData = true
            },
            onSelectCard: { field in
                selectedHealthField = field
            },
            isEmbedded: true
        )
    }

    private var deleteAccountSheet: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                    DSSectionHeader(
                        "删除账号",
                        subtitle: "这会删除账号相关的服务器数据，并清空本地登录状态。",
                        systemImage: "trash"
                    )

                    SecureField("输入密码确认", text: $deletePassword)
                        .font(.body.weight(.semibold))
                        .padding(DSTheme.Spacing.medium)
                        .background(DSTheme.Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                                .stroke(DSTheme.Color.border, lineWidth: 1)
                        }

                    if let errorMessage = appState.errorMessage {
                        AuthErrorBanner(message: errorMessage)
                    }

                    Button {
                        Task {
                            await deleteAccount()
                        }
                    } label: {
                        HStack(spacing: DSTheme.Spacing.small) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                            }

                            Text("永久删除")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)

                    Spacer()
                }
                .padding(DSTheme.Spacing.large)
            }
            .navigationTitle("删除账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showDeleteConfirmation = false
                    }
                }
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        if let deletedUserId = await appState.deleteAccount(password: deletePassword) {
            try? SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
                .deleteAll(userId: deletedUserId)
        }
        isDeleting = false
    }

    private func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profile = try await profileService.fetchProfile().profile
        } catch {
            profile = nil
        }
    }

    private func displaySex(_ sex: String) -> String {
        switch sex {
        case "female":
            "女性"
        case "male":
            "男性"
        case "other":
            "其他"
        default:
            "不想说明"
        }
    }
}

struct ProfileSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)
        }
    }
}

struct EditProfileSheet: View {
    let profile: UserProfile?
    let onSaved: (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var birthYear: String
    @State private var sex: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let profileService = ProfileService()

    init(profile: UserProfile?, onSaved: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSaved = onSaved
        self._displayName = State(initialValue: profile?.displayName ?? "")
        self._birthYear = State(initialValue: profile.map { String($0.birthYear) } ?? "")
        self._sex = State(initialValue: profile?.sex ?? "prefer_not_to_say")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "编辑 Profile",
                            subtitle: "更新轻量个人信息，用于整理读数和趋势上下文。",
                            systemImage: "person.text.rectangle"
                        )

                        DSCard {
                            VStack(spacing: DSTheme.Spacing.medium) {
                                ProfileEditField(title: "昵称", text: $displayName)
                                ProfileEditField(title: "出生年份", text: $birthYear, keyboardType: .numberPad)

                                Picker("性别", selection: $sex) {
                                    Text("女性").tag("female")
                                    Text("男性").tag("male")
                                    Text("其他").tag("other")
                                    Text("不想说明").tag("prefer_not_to_say")
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let errorMessage {
                            AuthErrorBanner(message: errorMessage)
                        }

                        DSPrimaryButton("保存 Profile", systemImage: "checkmark.circle.fill", isLoading: isSaving) {
                            Task {
                                await save()
                            }
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle("编辑 Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入昵称。"
            return
        }

        guard trimmedName.count <= 80 else {
            errorMessage = "昵称不能超过 80 个字符。"
            return
        }

        guard let year = Int(birthYear), year >= 1900, year <= Calendar.current.component(.year, from: Date()) else {
            errorMessage = "请输入有效出生年份。"
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let response = try await profileService.saveProfile(
                displayName: trimmedName,
                birthYear: year,
                sex: sex,
                heightCm: profile?.heightCm,
                weightKg: profile?.weightKg,
                todaySteps: profile?.todaySteps,
                exerciseMinutes: profile?.exerciseMinutes,
                restingHeartRate: profile?.restingHeartRate,
                sleepHours: profile?.sleepHours,
                healthDataSource: profile?.healthDataSource,
                healthDataSyncedAt: profile.flatMap(Self.syncedDate(from:))
            )
            if let profile = response.profile {
                onSaved(profile)
                dismiss()
            }
        } catch {
            errorMessage = "Profile 保存失败，请稍后重试。"
        }
    }

    private static func syncedDate(from profile: UserProfile) -> Date? {
        guard let value = profile.healthDataSyncedAt else {
            return nil
        }

        return fractionalISOFormatter.date(from: value) ?? standardISOFormatter.date(from: value)
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

struct ProfileEditField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)
                .textFieldStyle(.plain)
        }
        .padding(DSTheme.Spacing.medium)
        .background(DSTheme.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                .stroke(DSTheme.Color.border, lineWidth: 1)
        }
    }
}
