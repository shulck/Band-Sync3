import SwiftUI

struct AboutView: View {
    @State private var appVersion = "1.0.0"
    @State private var buildNumber = "1"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Шапка с логотипом
                VStack(spacing: 16) {
                    Image("AppIcon") // Убедитесь, что этот ресурс есть в ваших активах
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 8) {
                        Text("BandSync")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Making band management easy")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 20) {
                        VersionInfoBadge(title: "Version", value: appVersion)
                        VersionInfoBadge(title: "Build", value: buildNumber)
                        VersionInfoBadge(title: "Platform", value: "iOS")
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.top, 32)
                .padding(.bottom, 16)
                
                // Разделитель
                Divider()
                    .padding(.horizontal)
                
                // Правовая информация
                VStack(alignment: .leading, spacing: 5) {
                    Text("Legal Information")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    AboutNavigationLink(icon: "doc.text", title: "Privacy Policy", destination: EnhancedPrivacyPolicyView())
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    AboutNavigationLink(icon: "doc.plaintext", title: "Terms of Service", destination: EnhancedTermsOfServiceView())
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    AboutNavigationLink(icon: "text.book.closed", title: "Licenses & Acknowledgements", destination: EnhancedLicensesView())
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Социальные сети
                VStack(alignment: .leading, spacing: 5) {
                    Text("Connect With Us")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    AboutLinkButton(icon: "globe", title: "Visit Website", subtitle: "bandsync.example.com", url: "https://example.com/bandsync")
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    AboutLinkButton(icon: "bubble.left.and.bubble.right", title: "Follow on Twitter", subtitle: "@bandsync", url: "https://twitter.com/bandsync")
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    AboutLinkButton(icon: "camera", title: "Follow on Instagram", subtitle: "@bandsyncapp", url: "https://instagram.com/bandsyncapp")
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Сведения о правах
                VStack(spacing: 8) {
                    Text("Made with ❤️ by the BandSync Team")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("© 2025 BandSync. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle("About")
        .onAppear(perform: loadAppInfo)
    }
    
    func loadAppInfo() {
        // Get the app version and build number from the bundle
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
    }
}

struct VersionInfoBadge: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AboutNavigationLink<Destination: View>: View {
    var icon: String
    var title: String
    var destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

struct AboutLinkButton: View {
    var icon: String
    var title: String
    var subtitle: String
    var url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

struct EnhancedPrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Last updated: March 18, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Секции
                PolicySection(title: "Introduction", icon: "doc.text") {
                    Text("BandSync respects your privacy and is committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you use our application and tell you about your privacy rights.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                PolicySection(title: "What data do we collect?", icon: "list.bullet") {
                    Text("We collect personal identification information (Name, email address, phone number), profile information relevant to band management, event and setlist data that you create in the app, and usage data to improve the app experience.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Добавьте больше разделов политики конфиденциальности при необходимости
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

struct EnhancedTermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Last updated: March 18, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Секции
                PolicySection(title: "1. Terms", icon: "doc.plaintext") {
                    Text("By accessing the BandSync app, you are agreeing to be bound by these terms of service, all applicable laws and regulations, and agree that you are responsible for compliance with any applicable local laws.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Добавьте больше разделов условий использования при необходимости
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
    }
}

struct EnhancedLicensesView: View {
    var body: some View {
        List {
            Section {
                EnhancedLicenseRow(
                    name: "Firebase",
                    license: "Apache 2.0",
                    description: "A comprehensive app development platform",
                    url: "https://firebase.google.com"
                )
                
                EnhancedLicenseRow(
                    name: "SwiftUI",
                    license: "Apple License",
                    description: "User interface toolkit by Apple",
                    url: "https://developer.apple.com/xcode/swiftui/"
                )
                
                EnhancedLicenseRow(
                    name: "FSCalendar",
                    license: "MIT",
                    description: "A fully customizable calendar library",
                    url: "https://github.com/WenchaoD/FSCalendar"
                )
                // Добавьте больше лицензий по необходимости
            } header: {
                Text("OPEN SOURCE LIBRARIES")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                EnhancedLicenseRow(
                    name: "SF Symbols",
                    license: "Apple License",
                    description: "Icons designed by Apple",
                    url: "https://developer.apple.com/sf-symbols/"
                )
                // Добавьте больше атрибутов активов по необходимости
            } header: {
                Text("ASSETS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Licenses")
    }
}

struct EnhancedLicenseRow: View {
    var name: String
    var license: String
    var description: String
    var url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                Text(license)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Link("View License", destination: URL(string: url)!)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
}

struct PolicySection<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.title2)
                    .bold()
            }
            
            content
                .foregroundColor(.secondary)
                .padding(.leading, 26)
        }
        .padding(.bottom, 16)
    }
}
