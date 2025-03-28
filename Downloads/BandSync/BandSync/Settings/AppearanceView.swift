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
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    SettingToggleRow(
                        title: "Use System Theme",
                        icon: "iphone",
                        isOn: $useSystemTheme,
                        color: .blue
                    )
                    .onChange(of: useSystemTheme) { newValue in
                        saveAppearanceSettings()
                    }
                    
                    if !useSystemTheme {
                        Divider()
                        
                        SettingToggleRow(
                            title: "Dark Mode",
                            icon: "moon.fill",
                            isOn: $isDarkMode,
                            color: .purple
                        )
                        .onChange(of: isDarkMode) { newValue in
                            saveAppearanceSettings()
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                SectionHeaderView(title: "THEME", icon: "paintbrush.fill")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Size")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Picker("", selection: $fontSize) {
                        ForEach(0..<fontSizeOptions.count) { index in
                            Text(fontSizeOptions[index]).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: fontSize) { newValue in
                        saveAppearanceSettings()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("This is how your text will appear")
                            .font(fontSizeForPreview)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .padding(.top, 12)
                }
                .padding(.vertical, 8)
            } header: {
                SectionHeaderView(title: "TEXT SIZE", icon: "textformat.size")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose an accent color")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    // Color grid display
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(0..<accentColors.count, id: \.self) { index in
                            ColorOptionView(
                                color: accentColors[index],
                                name: accentColorNames[index],
                                isSelected: accentColorChoice == index
                            )
                            .onTapGesture {
                                accentColorChoice = index
                                saveAppearanceSettings()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(.vertical, 8)
            } header: {
                SectionHeaderView(title: "ACCENT COLOR", icon: "circle.hexagongrid.fill")
            }

            Section {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            
                        Text("Some appearance changes require restarting the app to take full effect.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        applyAppearanceChanges()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Apply Changes")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [accentColors[accentColorChoice], accentColors[accentColorChoice].opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: accentColors[accentColorChoice].opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            } header: {
                SectionHeaderView(title: "ACTIONS", icon: "gearshape.fill")
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

// MARK: - Supporting Components

// Удаляем дублирующее определение SectionHeaderView, так как оно уже объявлено в MoreView.swift

struct SettingToggleRow: View {
    var title: String
    var icon: String
    @Binding var isOn: Bool
    var color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.1))
                .cornerRadius(6)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct ColorOptionView: View {
    var color: Color
    var name: String
    var isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 2)
                
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? color : .secondary)
                .fontWeight(isSelected ? .semibold : .regular)
        }
    }
}

// Extension to check if key exists
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
