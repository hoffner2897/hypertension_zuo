import SwiftUI

struct AppRootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            switch appState.routeState {
            case .checkingSession:
                AppStatusView(title: "正在检查登录状态", systemImage: "lock.rotation")
            case .signedOut:
                AuthEntryView()
            case .profileSetup:
                ProfileSetupView()
            case .mainApp:
                MainTabView()
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

                Text(title)
                    .font(.headline)
                    .foregroundStyle(DSTheme.Color.textPrimary)
            }
        }
    }
}

#Preview {
    AppRootView()
}
