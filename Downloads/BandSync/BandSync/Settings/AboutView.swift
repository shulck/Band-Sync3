import SwiftUI

struct AboutView: View {
    @State private var appVersion = "1.0.0"
    @State private var buildNumber = "1"
    
    var body: some View {
        Form {
            Section(header: Text("Application")) {
                VStack(alignment: .center, spacing: 20) {
                    Image("AppIcon") // Make sure you have this in your assets
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .padding(.top, 20)
                    
                    Text("BandSync")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Making band management easy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Platform")
                    Spacer()
                    Text("iOS")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Legal")) {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Text("Privacy Policy")
                }
                
                NavigationLink(destination: TermsOfServiceView()) {
                    Text("Terms of Service")
                }
                
                NavigationLink(destination: LicensesView()) {
                    Text("Licenses & Acknowledgements")
                }
            }
            
            Section(header: Text("Connect")) {
                Link(destination: URL(string: "https://example.com/bandsync")!) {
                    HStack {
                        Text("Visit Website")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
                
                Link(destination: URL(string: "https://twitter.com/bandsync")!) {
                    HStack {
                        Text("Follow on Twitter")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
                
                Link(destination: URL(string: "https://instagram.com/bandsyncapp")!) {
                    HStack {
                        Text("Follow on Instagram")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section {
                VStack(spacing: 10) {
                    Text("Made with ❤️ by the BandSync Team")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("© 2025 BandSync. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
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

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 10)
                
                Text("Last updated: March 18, 2025")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                
                Text("Introduction")
                    .font(.title2)
                    .bold()
                
                Text("BandSync respects your privacy and is committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you use our application and tell you about your privacy rights.")
                    .padding(.bottom, 10)
                
                Text("What data do we collect?")
                    .font(.title2)
                    .bold()
                
                Text("We collect personal identification information (Name, email address, phone number), profile information relevant to band management, event and setlist data that you create in the app, and usage data to improve the app experience.")
                    .padding(.bottom, 10)
                
                // Add more privacy policy sections as needed
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 10)
                
                Text("Last updated: March 18, 2025")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                
                Text("1. Terms")
                    .font(.title2)
                    .bold()
                
                Text("By accessing the BandSync app, you are agreeing to be bound by these terms of service, all applicable laws and regulations, and agree that you are responsible for compliance with any applicable local laws.")
                    .padding(.bottom, 10)
                
                // Add more terms of service sections as needed
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section(header: Text("Open Source Libraries")) {
                LicenseRow(name: "Firebase", license: "Apache 2.0", url: "https://firebase.google.com")
                LicenseRow(name: "SwiftUI", license: "Apple License", url: "https://developer.apple.com/xcode/swiftui/")
                LicenseRow(name: "FSCalendar", license: "MIT", url: "https://github.com/WenchaoD/FSCalendar")
                // Add more licenses as needed
            }
            
            Section(header: Text("Assets")) {
                LicenseRow(name: "SF Symbols", license: "Apple License", url: "https://developer.apple.com/sf-symbols/")
                // Add more asset attributions as needed
            }
        }
        .navigationTitle("Licenses")
    }
}

struct LicenseRow: View {
    var name: String
    var license: String
    var url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            
            Text("License: \(license)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Link("View License", destination: URL(string: url)!)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
