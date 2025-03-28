import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var selectedLanguage: Language
    @State private var showingRestartAlert = false
    @Environment(\.presentationMode) var presentationMode

    init() {
        _selectedLanguage = State(initialValue: LocalizationManager.shared.currentLanguage)
    }

    var body: some View {
        Form {
            Section {
                ForEach(localizationManager.availableLanguages) { language in
                    Button(action: {
                        selectedLanguage = language
                    }) {
                        LanguageOptionRow(
                            language: language,
                            isSelected: selectedLanguage == language
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } header: {
                Text(localizationManager.localizedString("language", defaultValue: "Language"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)
            }

            Section {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text(localizationManager.localizedString("language_note", defaultValue: "Note: App will restart after changing language"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        applyLanguageChange()
                        showingRestartAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(localizationManager.localizedString("apply_changes", defaultValue: "Apply Changes"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(
                            selectedLanguage == localizationManager.currentLanguage ?
                                Color.gray :
                                Color.blue
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .disabled(selectedLanguage == localizationManager.currentLanguage)
                }
            }
        }
        .navigationTitle(localizationManager.localizedString("language_selection", defaultValue: "Language Selection"))
        .alert(isPresented: $showingRestartAlert) {
            Alert(
                title: Text(localizationManager.localizedString("language_changed", defaultValue: "Language Changed")),
                message: Text(localizationManager.localizedString("language_changed_to", defaultValue: "Language has been changed to") + " " + selectedLanguage.displayName),
                dismissButton: .default(Text(localizationManager.localizedString("ok", defaultValue: "OK"))) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    func applyLanguageChange() {
        if selectedLanguage != localizationManager.currentLanguage {
            // First save the new language
            localizationManager.setLanguage(selectedLanguage)

            // Force reload of the root view
            // This line will make the entire application redraw
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Send a special notification for complete UI reload
                NotificationCenter.default.post(
                    name: NSNotification.Name("ForceAppReload"),
                    object: nil
                )
            }
        }
    }
}

struct LanguageOptionRow: View {
    var language: Language
    var isSelected: Bool
    
    var body: some View {
        HStack {
            // Флаг или иконка языка
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                    .frame(width: 44, height: 44)
                
                Text(getFlagEmoji(for: language))
                    .font(.title)
            }
            .padding(.trailing, 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(language.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .blue : .primary)
                
                // Используем displayName или id в качестве резервного варианта
                Text(getLanguageNativeName(for: language))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    // Функция для получения нативного названия языка
    func getLanguageNativeName(for language: Language) -> String {
        // Словарь с нативными названиями для распространенных языков
        let nativeNames: [String: String] = [
            "en": "English",
            "es": "Español",
            "fr": "Français",
            "de": "Deutsch",
            "it": "Italiano",
            "ru": "Русский",
            "zh": "中文",
            "ja": "日本語"
        ]
        
        // Попробуем получить идентификатор языка из displayName или id
        if let identifier = getLanguageIdentifier(for: language),
           let nativeName = nativeNames[identifier] {
            return nativeName
        }
        
        // Если не удалось определить нативное название, возвращаем displayName
        return language.displayName
    }
    
    // Функция для получения идентификатора языка
    func getLanguageIdentifier(for language: Language) -> String? {
        // Попробуем извлечь код из displayName (например, "English (en)" -> "en")
        if let codeInParentheses = language.displayName.range(of: #"\(([a-z]{2})\)"#, options: .regularExpression) {
            let startIndex = language.displayName.index(codeInParentheses.lowerBound, offsetBy: 1)
            let endIndex = language.displayName.index(codeInParentheses.upperBound, offsetBy: -1)
            return String(language.displayName[startIndex..<endIndex])
        }
        
        // Определяем языковой код на основе displayName
        let lowerDisplayName = language.displayName.lowercased()
        if lowerDisplayName.contains("english") { return "en" }
        if lowerDisplayName.contains("español") || lowerDisplayName.contains("spanish") { return "es" }
        if lowerDisplayName.contains("français") || lowerDisplayName.contains("french") { return "fr" }
        if lowerDisplayName.contains("deutsch") || lowerDisplayName.contains("german") { return "de" }
        if lowerDisplayName.contains("italiano") || lowerDisplayName.contains("italian") { return "it" }
        if lowerDisplayName.contains("русский") || lowerDisplayName.contains("russian") { return "ru" }
        if lowerDisplayName.contains("中文") || lowerDisplayName.contains("chinese") { return "zh" }
        if lowerDisplayName.contains("日本語") || lowerDisplayName.contains("japanese") { return "ja" }
        
        return nil
    }
    
    // Функция для получения эмодзи флага
    func getFlagEmoji(for language: Language) -> String {
        if let identifier = getLanguageIdentifier(for: language) {
            switch identifier {
            case "en": return "🇺🇸"
            case "es": return "🇪🇸"
            case "fr": return "🇫🇷"
            case "de": return "🇩🇪"
            case "it": return "🇮🇹"
            case "ru": return "🇷🇺"
            case "zh": return "🇨🇳"
            case "ja": return "🇯🇵"
            default: return "🌐"
            }
        }
        return "🌐"
    }
}
