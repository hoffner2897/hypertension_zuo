//
//  MainTabView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .today
    @State private var todayActionItems = TodayActionItem.demoItems()

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayActionView(
                items: $todayActionItems,
                userId: appState.currentUser?.id ?? "",
                onOpenBloodPressure: {
                    selectedTab = .bloodPressure
                }
            )
            .tabItem {
                Label("今日行动", systemImage: "figure.walk.motion")
            }
            .tag(MainTab.today)

            BloodPressureHomeView(userId: appState.currentUser?.id ?? "")
            .tabItem {
                Label("血压读数", systemImage: "heart.text.square")
            }
            .tag(MainTab.bloodPressure)

            ActionGenerateDemoView(
                userId: appState.currentUser?.id ?? "",
                onGenerateAction: { item in
                    upsertTodayAction(item)
                    selectedTab = .today
                }
            )
            .tabItem {
                Label("行动生成", systemImage: "figure.walk.motion")
            }
            .tag(MainTab.actionGenerate)

            ActionAdjustDemoView(
                items: $todayActionItems,
                userId: appState.currentUser?.id ?? ""
            )
            .tabItem {
                Label("行动调整", systemImage: "slider.horizontal.3")
            }
            .tag(MainTab.actionAdjust)
        }
        .tint(DSTheme.Color.primary)
    }

    private func upsertTodayAction(_ item: TodayActionItem) {
        if let index = todayActionItems.firstIndex(where: {
            $0.title == item.title &&
            Calendar.current.isDate($0.scheduledStartAt, equalTo: item.scheduledStartAt, toGranularity: .minute)
        }) {
            let existingItem = todayActionItems[index]
            let keepsExistingExerciseSync = existingItem.exerciseId != nil && item.exerciseId == nil
            let replacement = TodayActionItem(
                id: existingItem.id,
                type: item.type,
                title: item.title,
                description: item.description,
                reason: item.reason,
                scheduledStartAt: item.scheduledStartAt,
                durationMinutes: item.durationMinutes,
                status: item.status,
                completedAt: item.completedAt,
                sortOrder: item.sortOrder,
                bloodPressureText: item.bloodPressureText,
                adviceText: item.adviceText,
                exerciseId: keepsExistingExerciseSync ? "custom-adjusted" : item.exerciseId,
                exerciseScene: keepsExistingExerciseSync ? existingItem.exerciseScene : item.exerciseScene,
                exerciseEnergy: keepsExistingExerciseSync ? existingItem.exerciseEnergy : item.exerciseEnergy,
                exerciseContexts: keepsExistingExerciseSync ? existingItem.exerciseContexts : item.exerciseContexts,
                exerciseMovementAdvice: keepsExistingExerciseSync ? item.description : item.exerciseMovementAdvice,
                exerciseIntensityAdvice: keepsExistingExerciseSync
                    ? "保持自然呼吸和舒适节奏；如有明显不适，请停止并休息。"
                    : item.exerciseIntensityAdvice,
                clientUpdatedAt: Date()
            )
            todayActionItems[index] = replacement
        } else {
            todayActionItems.append(item)
        }

        todayActionItems.sort { $0.scheduledStartAt < $1.scheduledStartAt }
        for index in todayActionItems.indices {
            todayActionItems[index].sortOrder = index
        }
    }
}

private enum MainTab: Hashable {
    case today
    case bloodPressure
    case actionGenerate
    case actionAdjust
}

private struct HealthProfileTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var healthViewModel = HealthKitSummaryViewModel()
    @State private var profile: UserProfile?
    @State private var isLoadingProfile = false
    @State private var showEditProfile = false
    @State private var showDeleteConfirmation = false
    @State private var deletePassword = ""
    @State private var isDeleting = false
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
                        accountSection
                        healthSection
                        accountActions
                    }
                    .padding(DSTheme.Spacing.large)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Health Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(profile: profile) { updatedProfile in
                    profile = updatedProfile
                    appState.completeProfile(updatedProfile)
                }
            }
            .sheet(isPresented: $showDeleteConfirmation) {
                deleteAccountSheet
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
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
            DSSectionHeader(
                "账号",
                subtitle: "管理登录状态、个人资料和健康基础数据。",
                systemImage: "person.crop.circle"
            )

            DSCard {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                    Text(appState.currentEmail)
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Text("已登录。血压读数和健康背景会同步到这个账号。")
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
        }
    }

    private var healthSection: some View {
        SyncedHealthDataContent(
            viewModel: healthViewModel,
            primaryTitle: healthViewModel.primaryActionTitle,
            primaryIcon: healthViewModel.primaryActionIcon,
            isPrimaryDisabled: false,
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

    private var accountActions: some View {
        VStack(spacing: DSTheme.Spacing.small) {
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

    private func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profile = try await profileService.fetchProfile().profile
        } catch {
            profile = nil
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        await appState.deleteAccount(password: deletePassword)
        isDeleting = false
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

#Preview {
    MainTabView()
}
