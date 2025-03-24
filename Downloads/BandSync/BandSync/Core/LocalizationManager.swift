import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language {
        didSet {
            // Save selected language to UserDefaults
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            updateLocale()

            // Publish notification about language change
            NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
        }
    }

    // Available app languages according to requirements
    let availableLanguages: [Language] = [.english, .german, .ukrainian]

    private init() {
        // Get saved language or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Determine language by system settings
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"

            if preferredLanguage.hasPrefix("de") {
                self.currentLanguage = .german
            } else if preferredLanguage.hasPrefix("uk") {
                self.currentLanguage = .ukrainian
            } else {
                self.currentLanguage = .english
            }
        }

        updateLocale()
    }

    private func updateLocale() {
        // Set locale for the application
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    // Function to get localized string
    func localizedString(_ key: String, defaultValue: String = "") -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            print("❌ Could not find localization bundle for \(currentLanguage.rawValue)")
            return defaultValue.isEmpty ? key : defaultValue
        }

        let localizedString = NSLocalizedString(key, tableName: "Localizable",
                                                bundle: bundle,
                                                value: defaultValue.isEmpty ? key : defaultValue,
                                                comment: "")

        return localizedString
    }

    // Function to change language
    func setLanguage(_ language: Language) {
        self.currentLanguage = language
    }
}

// Enumeration of supported languages
enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"
    case ukrainian = "uk"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .english: return "English 🇬🇧"
        case .german: return "Deutsch 🇩🇪"
        case .ukrainian: return "Українська 🇺🇦"
        }
    }

    var locale: Locale {
        return Locale(identifier: self.rawValue)
    }
}

// Environment for injecting language settings into SwiftUI
struct LocalizationEnvironmentKey: EnvironmentKey {
    static let defaultValue: Language = .english
}

extension EnvironmentValues {
    var currentLanguage: Language {
        get { self[LocalizationEnvironmentKey.self] }
        set { self[LocalizationEnvironmentKey.self] = newValue }
    }
}
