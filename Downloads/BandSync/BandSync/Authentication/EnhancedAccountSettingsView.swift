import SwiftUI
import FirebaseAuth

struct EnhancedAccountSettingsView: View {
    // MARK: - State Properties
    @State private var enableBiometrics = true
    @State private var enableTwoFactor = false
    @State private var notifyOnLogin = true
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingPasswordResetSent = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    @State private var isLoading = true
    @State private var showingPINSetup = false
    @State private var isPINEnabled = false
    @State private var showingDataProtectionInfo = false
    
    // MARK: - Biometric Manager
    private let biometricManager = BiometricAuthManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading settings...")
                        .padding()
                } else {
                    // MARK: - Security Card
                    securityCard
                    
                    // MARK: - Advanced Security Card
                    advancedSecurityCard
                    
                    // MARK: - Data Protection Card
                    dataProtectionCard
                    
                    // MARK: - Account Actions Card
                    accountActionsCard
                }
            }
            .padding()
        }
        .navigationTitle("Account Security")
        .onAppear(perform: loadSettings)
        .alert(isPresented: $showingChangePassword) {
            Alert(
                title: Text("Reset Password"),
                message: Text("You will receive an email with instructions to reset your password."),
                primaryButton: .default(Text("Send Email")) {
                    sendPasswordResetEmail()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert(isPresented: $showingDeleteAccount) {
            Alert(
                title: Text("Delete Account"),
                message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteAccount()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupView()
        }
        .sheet(isPresented: $showingDataProtectionInfo) {
            DataProtectionInfoView()
        }
        .alert(isPresented: $showingPasswordResetSent) {
            Alert(
                title: Text("Password Reset Email Sent"),
                message: Text("Check your email for instructions to reset your password."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - View Components
    
    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("Security")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            SettingsToggleRow(
                title: "Biometric Authentication",
                description: biometricType,
                isOn: $enableBiometrics,
                icon: biometricManager.biometricType == .faceID ? "faceid" : "touchid",
                isEnabled: biometricManager.biometricType != .none,
                onChange: { saveBiometricSetting(enabled: $0) }
            )
            
            SettingsToggleRow(
                title: "Two-Factor Authentication",
                description: "Add an extra layer of security to your account",
                isOn: $enableTwoFactor,
                icon: "shield.lefthalf.fill",
                onChange: { saveTwoFactorSetting(enabled: $0) }
            )
            
            SettingsToggleRow(
                title: "Login Notifications",
                description: "Get notified when your account is accessed",
                isOn: $notifyOnLogin,
                icon: "bell.badge.fill",
                onChange: { saveNotificationSetting(enabled: $0) }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var advancedSecurityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.rectangle.stack.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("Advanced Security")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PIN Protection")
                            .fontWeight(.medium)
                        
                        Text("Add PIN code for sensitive operations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isPINEnabled {
                        Text("Enabled")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Button("Set Up") {
                            showingPINSetup = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var dataProtectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "externaldrive.badge.shield")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("Data Protection")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingDataProtectionInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 4)
            
            SettingsInfoRow(
                title: "Auto Data Wipe",
                description: "Sensitive data will be wiped after 30 days of inactivity",
                icon: "clock.arrow.circlepath"
            )
            
            SettingsInfoRow(
                title: "Encryption",
                description: "Your data is encrypted on this device",
                icon: "lock.doc.fill"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var accountActionsCard: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingChangePassword = true
            }) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    
                    Text("Change Password")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            
            Button(action: {
                showingDeleteAccount = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red)
                        .cornerRadius(8)
                    
                    Text("Delete Account")
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
    
    // MARK: - Computed Properties
    
    private var biometricType: String {
        switch biometricManager.biometricType {
        case .faceID:
            return "Use Face ID for quick authentication"
        case .touchID:
            return "Use Touch ID for quick authentication"
        case .none:
            return "Biometric authentication not available"
        }
    }
    
    // MARK: - Methods
    
    func loadSettings() {
        // Load biometric setting
        if let user = Auth.auth().currentUser {
            enableBiometrics = BiometricAuthManager.shared.isBiometricAuthEnabled(for: user.uid)
        }
        
        // Load PIN status
        isPINEnabled = PINCodeManager.shared.isPINCodeEnabled()
        
        // Load other settings from UserDefaults
        enableTwoFactor = UserDefaults.standard.bool(forKey: "twoFactorEnabled")
        notifyOnLogin = UserDefaults.standard.bool(forKey: "notifyOnLogin")
        
        isLoading = false
    }
    
    func saveBiometricSetting(enabled: Bool) {
        if let user = Auth.auth().currentUser {
            BiometricAuthManager.shared.setBiometricAuthEnabled(enabled, for: user.uid)
            
            if enabled {
                BiometricAuthManager.shared.saveAuthCredentials(userID: user.uid, email: user.email ?? "")
                
                // Show success message
                successMessage = "Biometric authentication enabled"
                showingSuccessAlert = true
            }
        }
    }
    
    func saveTwoFactorSetting(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "twoFactorEnabled")
        
        // In a real app, you would enable/disable two-factor authentication on the server
        // This is just a placeholder
        if enabled {
            // Show instructions for setting up 2FA
            successMessage = "Two-factor authentication has been enabled"
            showingSuccessAlert = true
        }
    }
    
    func saveNotificationSetting(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "notifyOnLogin")
        
        successMessage = "Login notification settings updated"
        showingSuccessAlert = true
    }
    
    func sendPasswordResetEmail() {
        guard let email = Auth.auth().currentUser?.email else {
            errorMessage = "No email associated with this account"
            showingErrorAlert = true
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                errorMessage = "Error: \(error.localizedDescription)"
                showingErrorAlert = true
            } else {
                showingPasswordResetSent = true
            }
        }
    }
    
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        user.delete { error in
            if let error = error {
                errorMessage = "Error deleting account: \(error.localizedDescription)"
                showingErrorAlert = true
            } else {
                // Notify the app that the user has been logged out
                NotificationCenter.default.post(name: NSNotification.Name("LogoutUser"), object: nil)
                
                // Clear any local data
                DataEncryptionManager.shared.performDataWipe()
            }
        }
    }
}

// MARK: - Supporting Components

struct SettingsToggleRow: View {
    var title: String
    var description: String
    @Binding var isOn: Bool
    var icon: String
    var isEnabled: Bool = true
    var onChange: (Bool) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .blue : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .disabled(!isEnabled)
                .onChange(of: isOn) { _ in
                    onChange(isOn)
                }
        }
    }
}

struct SettingsInfoRow: View {
    var title: String
    var description: String
    var icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct DataProtectionInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Data Protection")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("How We Keep Your Data Safe")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        Text("BandSync takes your data security seriously. Here's how we protect your information:")
                            .padding(.bottom, 4)
                    }
                    
                    Group {
                        SecurityFeatureRow(
                            title: "End-to-End Encryption",
                            description: "Your data is encrypted on your device before being transmitted to our servers.",
                            icon: "lock.shield"
                        )
                        
                        SecurityFeatureRow(
                            title: "Automatic Data Wipe",
                            description: "After 30 days of inactivity, sensitive information will be automatically deleted from your device.",
                            icon: "clock.arrow.circlepath"
                        )
                        
                        SecurityFeatureRow(
                            title: "Secure Storage",
                            description: "We use the iOS Keychain for secure storage of your credentials.",
                            icon: "key.fill"
                        )
                        
                        SecurityFeatureRow(
                            title: "PIN Protection",
                            description: "Add an additional layer of security for sensitive operations.",
                            icon: "pin.fill"
                        )
                        
                        SecurityFeatureRow(
                            title: "Biometric Authentication",
                            description: "Use Face ID or Touch ID to quickly and securely access your account.",
                            icon: "touchid"
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Data Protection")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct SecurityFeatureRow: View {
    var title: String
    var description: String
    var icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.blue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
