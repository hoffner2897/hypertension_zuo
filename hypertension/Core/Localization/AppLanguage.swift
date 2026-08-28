import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

@MainActor
final class AppLanguageStore: ObservableObject {
    static let preferenceKey = "bphealth.appLanguage"
    static let refreshTokenKey = "bphealth.refreshToken"
    static let deviceIdKey = "bphealth.deviceId"

    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Self.preferenceKey)
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.preferenceKey),
           let language = AppLanguage(rawValue: saved) {
            selectedLanguage = language
            return
        }

        // Preserve Chinese for people who already used an earlier build. A truly
        // new install follows the device language until the user chooses explicitly.
        let isExistingInstallation = KeychainStore.read(Self.refreshTokenKey) != nil
            || KeychainStore.read(Self.deviceIdKey) != nil
        if isExistingInstallation {
            selectedLanguage = .simplifiedChinese
        } else {
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            selectedLanguage = preferred.hasPrefix("zh") ? .simplifiedChinese : .english
        }
    }

    var locale: Locale { selectedLanguage.locale }
}

enum L10n {
    static var language: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: AppLanguageStore.preferenceKey),
           let language = AppLanguage(rawValue: saved) {
            return language
        }

        let isExistingInstallation = KeychainStore.read(AppLanguageStore.refreshTokenKey) != nil
            || KeychainStore.read(AppLanguageStore.deviceIdKey) != nil
        if isExistingInstallation {
            return .simplifiedChinese
        }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    static var locale: Locale { language.locale }

    static func string(_ key: String) -> String {
        localizedBundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
