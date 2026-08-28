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

                                Picker(L10n.string("性别"), selection: $sex) {
                                    Text(L10n.string("女性")).tag("female")
                                    Text(L10n.string("男性")).tag("male")
                                    Text(L10n.string("其他")).tag("other")
                                    Text(L10n.string("不想说明")).tag("prefer_not_to_say")
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let errorMessage {
                            AuthErrorBanner(message: errorMessage)
                        }

                        DSPrimaryButton(L10n.string("进入 BPHealth"), systemImage: "arrow.right.circle.fill", isLoading: isSaving) {
                            Task {
                                await save()
                            }
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle(L10n.string("Profile"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = L10n.string("请输入昵称。")
            return
        }

        guard trimmedName.count <= 80 else {
            errorMessage = L10n.string("昵称不能超过 80 个字符。")
            return
        }

        guard let year = Int(birthYear), year >= 1900, year <= Calendar.current.component(.year, from: Date()) else {
            errorMessage = L10n.string("请输入有效出生年份。")
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
            errorMessage = L10n.string("Profile 保存失败，请稍后重试。")
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
            Text(L10n.string(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            TextField(L10n.string(title), text: $text)
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
