import SwiftUI

struct AppRootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if let requiredUpdate = appState.requiredUpdate {
                RequiredUpdateView(requirement: requiredUpdate)
            } else {
                switch appState.routeState {
                case .checkingSession:
                    AppStatusView(title: "正在检查登录状态", systemImage: "lock.rotation")
                case .signedOut:
                    AuthEntryView()
                case .verifyEmail:
                    VerifyEmailView(email: appState.currentEmail)
                case .profileSetup:
                    ProfileSetupView()
                case .mainApp:
                    MainTabView()
                }
            }
        }
        .environmentObject(appState)
        .task {
            if case .checkingSession = appState.routeState {
                await appState.bootstrap()
            }
        }
    }
}

private struct RequiredUpdateView: View {
    let requirement: RequiredAppUpdate

    @Environment(\.openURL) private var openURL

    private var updateURL: URL {
        requirement.updateURL
            ?? URL(string: "https://testflight.apple.com/join/TyhR9xzw")!
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: DSTheme.Spacing.large) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(DSTheme.Color.primary)

                VStack(spacing: DSTheme.Spacing.small) {
                    Text(L10n.string("需要更新"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Text(L10n.string("为了继续使用 BPHealth，请更新到最新测试版本。"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }

                Button {
                    openURL(updateURL)
                } label: {
                    Text(L10n.string("前往 TestFlight 更新"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSTheme.Spacing.small)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSTheme.Color.primary)
            }
            .padding(DSTheme.Spacing.large)
        }
    }
}

private struct AppStatusView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: DSTheme.Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(DSTheme.Color.primary)

                ProgressView()

                Text(L10n.string(title))
                    .font(.headline)
                    .foregroundStyle(DSTheme.Color.textPrimary)
            }
        }
    }
}

#Preview {
    AppRootView()
}
