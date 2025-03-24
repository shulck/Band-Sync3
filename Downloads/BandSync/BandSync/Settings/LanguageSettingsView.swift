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
            Section(header: Text(localizationManager.localizedString("language", defaultValue: "Language"))) {
                ForEach(localizationManager.availableLanguages) { language in
                    Button(action: {
                        selectedLanguage = language
                    }) {
                        HStack {
                            Text(language.displayName)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }

            Section {
                Button(action: {
                    applyLanguageChange()
                    showingRestartAlert = true
                }) {
                    Text(localizationManager.localizedString("apply_changes", defaultValue: "Apply Changes"))
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(selectedLanguage == localizationManager.currentLanguage)
            }

            Section {
                Text(localizationManager.localizedString("language_note", defaultValue: "Note: App will restart after changing language"))
                    .font(.caption)
                    .foregroundColor(.gray)
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
