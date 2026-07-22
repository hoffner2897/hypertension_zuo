import SwiftUI

struct AuthEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var isPreparingTestSession = false
    @State private var localError: String?
    #if DEBUG
    @State private var isShowingHealthConnectTest = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            mode.title,
                            subtitle: mode.subtitle,
                            systemImage: "person.crop.circle.badge.checkmark"
                        )

                        Picker("Mode", selection: $mode) {
                            Text("登录").tag(AuthMode.login)
                            Text("注册").tag(AuthMode.register)
                        }
                        .pickerStyle(.segmented)

                        DSCard {
                            VStack(spacing: DSTheme.Spacing.medium) {
                                AuthTextField(title: "邮箱", text: $email, keyboardType: .emailAddress)
                                AuthSecureField(title: "密码", text: $password)

                                if mode == .register {
                                    AuthSecureField(title: "确认密码", text: $confirmPassword)
                                }
                            }
                        }

                        if let message = localError ?? appState.errorMessage {
                            AuthErrorBanner(message: message)
                        }

                        DSPrimaryButton(mode.buttonTitle, systemImage: mode.buttonIcon, isLoading: isLoading) {
                            Task {
                                await submit()
                            }
                        }
                        .disabled(isPreparingTestSession)

                        #if DEBUG
                        Button {
                            Task {
                                isPreparingTestSession = true
                                await appState.enterDebugTestSession()
                                isPreparingTestSession = false
                            }
                        } label: {
                            Group {
                                if isPreparingTestSession {
                                    HStack(spacing: DSTheme.Spacing.small) {
                                        ProgressView()
                                        Text("正在准备测试版…")
                                    }
                                } else {
                                    Label("免注册进入测试版", systemImage: "hammer.circle.fill")
                                }
                            }
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(DSTheme.Color.primary)
                        .disabled(isLoading || isPreparingTestSession)
                        .accessibilityIdentifier("auth.debugPreviewButton")

                        Button {
                            isShowingHealthConnectTest = true
                        } label: {
                            Label("测试 Apple Health 连接界面", systemImage: "heart.text.square.fill")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(DSTheme.Color.primary)
                        .disabled(isLoading || isPreparingTestSession)
                        .accessibilityIdentifier("auth.healthConnectPreviewButton")

                        Text("仅开发包显示。连接测试后端，可直接使用账号同步与在线 AI。")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DSTheme.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                        #endif
                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
            .sheet(isPresented: $isShowingHealthConnectTest) {
                HealthConnectView(
                    onConnect: {
                        isShowingHealthConnectTest = false
                    },
                    onSkip: {
                        isShowingHealthConnectTest = false
                    }
                )
            }
            #endif
        }
    }

    private func submit() async {
        localError = nil

        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            localError = "请输入邮箱。"
            return
        }

        guard password.count >= 8 else {
            localError = "密码至少需要 8 位。"
            return
        }

        if mode == .register, password != confirmPassword {
            localError = "两次输入的密码不一致。"
            return
        }

        isLoading = true
        switch mode {
        case .login:
            await appState.login(email: email, password: password)
        case .register:
            await appState.register(email: email, password: password)
        }
        isLoading = false
    }
}

private enum AuthMode {
    case login
    case register

    var title: String {
        switch self {
        case .login:
            "欢迎回来"
        case .register:
            "创建账号"
        }
    }

    var subtitle: String {
        switch self {
        case .login:
            "登录后同步你的血压读数和个人资料。"
        case .register:
            "注册后填写轻量 profile，即可开始记录。"
        }
    }

    var buttonTitle: String {
        switch self {
        case .login:
            "登录"
        case .register:
            "注册"
        }
    }

    var buttonIcon: String {
        switch self {
        case .login:
            "arrow.right.circle.fill"
        case .register:
            "person.badge.plus"
        }
    }

    var navigationTitle: String {
        switch self {
        case .login:
            "登录"
        case .register:
            "注册"
        }
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
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

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            SecureField(title, text: $text)
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

struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DSTheme.Color.warning)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DSTheme.Spacing.medium)
        .background(DSTheme.Color.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
    }
}
