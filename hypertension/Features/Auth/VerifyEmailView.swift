import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject private var appState: AppState
    let email: String

    @State private var token = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "验证邮箱",
                            subtitle: "开发阶段验证链接会打印在 server console。复制 token 后在这里完成验证。",
                            systemImage: "envelope.badge.shield.half.filled"
                        )

                        DSCard {
                            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                                Text(email)
                                    .font(.headline)
                                    .foregroundStyle(DSTheme.Color.textPrimary)

                                TextField("ver_...", text: $token)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.body.weight(.semibold))
                                    .padding(DSTheme.Spacing.medium)
                                    .background(DSTheme.Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                                            .stroke(DSTheme.Color.border, lineWidth: 1)
                                    }
                            }
                        }

                        if let message = notice ?? appState.errorMessage {
                            AuthErrorBanner(message: message)
                        }

                        VStack(spacing: DSTheme.Spacing.small) {
                            DSPrimaryButton("完成验证", systemImage: "checkmark.seal.fill", isLoading: isVerifying) {
                                Task {
                                    await verify()
                                }
                            }

                            DSSecondaryButton(isResending ? "发送中" : "重新发送验证链接", systemImage: "arrow.clockwise", isDisabled: isResending) {
                                Task {
                                    await resend()
                                }
                            }

                            DSSecondaryButton("退出登录", systemImage: "rectangle.portrait.and.arrow.right") {
                                Task {
                                    await appState.logout()
                                }
                            }
                        }
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle("验证邮箱")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func verify() async {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = "请输入验证 token。"
            return
        }

        notice = nil
        isVerifying = true
        await appState.verifyEmail(token: token)
        isVerifying = false
    }

    private func resend() async {
        notice = nil
        isResending = true
        await appState.resendVerification()
        if appState.errorMessage == nil {
            notice = "新的验证链接已打印到 server console。"
        }
        isResending = false
    }
}
