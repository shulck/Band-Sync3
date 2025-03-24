import SwiftUI

struct AppearanceSettingsView: View {
    @State private var isDarkMode = false
    @State private var fontSize = 1 // 0: Small, 1: Medium, 2: Large
    @State private var useSystemTheme = true
    @State private var accentColorChoice = 0

    let fontSizeOptions = ["Small", "Medium", "Large"]
    let accentColors: [Color] = [.blue, .red, .green, .orange, .purple, .pink]
    let accentColorNames = ["Blue", "Red", "Green", "Orange", "Purple", "Pink"]

    var body: some View {
        Form {
            Section(header: Text("Theme")) {
                Toggle("Use System Theme", isOn: $useSystemTheme)
                    .onChange(of: useSystemTheme) { newValue in
                        saveAppearanceSettings()
                    }

                if !useSystemTheme {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                        .onChange(of: isDarkMode) { newValue in
                            saveAppearanceSettings()
                        }
                }
            }

            Section(header: Text("Text Size")) {
                Picker("Font Size", selection: $fontSize) {
                    ForEach(0..<fontSizeOptions.count) { index in
                        Text(fontSizeOptions[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: fontSize) { newValue in
                    saveAppearanceSettings()
                }

                HStack {
                    Text("Preview")
                        .font(fontSizeForPreview)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Accent Color")) {
                Picker("Accent Color", selection: $accentColorChoice) {
                    ForEach(0..<accentColors.count) { index in
                        HStack {
                            Circle()
                                .fill(accentColors[index])
                                .frame(width: 20, height: 20)
                            Text(accentColorNames[index])
                        }
                        .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 100)
                .onChange(of: accentColorChoice) { newValue in
                    saveAppearanceSettings()
                }
            }

            Section(header: Text("Info")) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)

                    Text("Some appearance changes require restarting the app to take full effect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                Button("Apply Changes") {
                    applyAppearanceChanges()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Appearance")
        .onAppear(perform: loadAppearanceSettings)
    }

    var fontSizeForPreview: Font {
        switch fontSize {
        case 0:
            return .system(.subheadline)
        case 1:
            return .system(.body)
        case 2:
            return .system(.title3)
        default:
            return .system(.body)
        }
    }

    func loadAppearanceSettings() {
        // Load settings from UserDefaults
        useSystemTheme = UserDefaults.standard.bool(forKey: "useSystemTheme")
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        fontSize = UserDefaults.standard.integer(forKey: "fontSize")
        accentColorChoice = UserDefaults.standard.integer(forKey: "accentColorChoice")

        // If settings are not found, set default values
        if !UserDefaults.standard.contains(key: "useSystemTheme") {
            useSystemTheme = true
        }

        if !UserDefaults.standard.contains(key: "fontSize") {
            fontSize = 1 // Medium by default
        }

        if !UserDefaults.standard.contains(key: "accentColorChoice") {
            accentColorChoice = 0 // Blue by default
        }
    }

    func saveAppearanceSettings() {
        UserDefaults.standard.set(useSystemTheme, forKey: "useSystemTheme")
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(fontSize, forKey: "fontSize")
        UserDefaults.standard.set(accentColorChoice, forKey: "accentColorChoice")
    }

    func applyAppearanceChanges() {
        // Save settings
        saveAppearanceSettings()

        // Notify the app to apply changes
        NotificationCenter.default.post(name: NSNotification.Name("AppearanceChanged"), object: nil)
    }
}

// Extension to check if key exists
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
