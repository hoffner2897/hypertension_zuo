import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var displayName = ""
    @State private var birthYear = ""
    @State private var sex = "prefer_not_to_say"
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let profileService = ProfileService()

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "完善 Profile",
                            subtitle: "只需要轻量信息，用于整理读数和趋势上下文。",
                            systemImage: "person.text.rectangle"
                        )

                        DSCard {
                            VStack(spacing: DSTheme.Spacing.medium) {
                                AuthTextInput(title: "昵称", text: $displayName)
                                AuthTextInput(title: "出生年份", text: $birthYear, keyboardType: .numberPad)

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

                        DSPrimaryButton("进入 BPHealth", systemImage: "arrow.right.circle.fill", isLoading: isSaving) {
                            Task {
                                await save()
                            }
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入昵称。"
            return
        }

        guard let year = Int(birthYear), year >= 1900, year <= Calendar.current.component(.year, from: Date()) else {
            errorMessage = "请输入有效出生年份。"
            return
        }

        isSaving = true
        do {
            let response = try await profileService.saveProfile(displayName: trimmedName, birthYear: year, sex: sex)
            if let profile = response.profile {
                appState.completeProfile(profile)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Profile 保存失败，请稍后重试。"
        }
        isSaving = false
    }
}

private struct AuthTextInput: View {
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
