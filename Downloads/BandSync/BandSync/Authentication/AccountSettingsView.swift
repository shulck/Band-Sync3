import SwiftUI
import FirebaseAuth

struct AccountSettingsView: View {
    @State private var enableBiometrics = true
    @State private var enableTwoFactor = false
    @State private var notifyOnLogin = true
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("Security")) {
                Toggle("Enable Biometric Login", isOn: $enableBiometrics)
                    .onChange(of: enableBiometrics) { newValue in
                        saveBiometricSetting(enabled: newValue)
                    }
                
                Toggle("Two-Factor Authentication", isOn: $enableTwoFactor)
                    .onChange(of: enableTwoFactor) { newValue in
                        saveTwoFactorSetting(enabled: newValue)
                    }
                
                Toggle("Notify on New Login", isOn: $notifyOnLogin)
                    .onChange(of: notifyOnLogin) { newValue in
                        saveNotificationSetting(enabled: newValue)
                    }
                
                NavigationLink(destination: AccountSettingsView()) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                        Text("Advanced Security Settings")
                    }
                }
            }
            
            Section {
                Button(action: { showingChangePassword = true }) {
                    Text("Change Password")
                        .foregroundColor(.blue)
                }
                
                Button(action: { showingDeleteAccount = true }) {
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Account Settings")
        .onAppear(perform: loadSettings)
        .alert(isPresented: $showingChangePassword) {
            Alert(
                title: Text("Change Password"),
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
    }
    
    func loadSettings() {
        // Load biometric setting
        if let user = Auth.auth().currentUser {
            enableBiometrics = BiometricAuthManager.shared.isBiometricAuthEnabled(for: user.uid)
        }
        
        // In a real app, you would load these settings from a database or user defaults
        // For now, we'll just use default values
        enableTwoFactor = UserDefaults.standard.bool(forKey: "twoFactorEnabled")
        notifyOnLogin = UserDefaults.standard.bool(forKey: "notifyOnLogin")
    }
    
    func saveBiometricSetting(enabled: Bool) {
        if let user = Auth.auth().currentUser {
            BiometricAuthManager.shared.setBiometricAuthEnabled(enabled, for: user.uid)
            
            if enabled {
                BiometricAuthManager.shared.saveAuthCredentials(userID: user.uid, email: user.email ?? "")
            }
        }
    }
    
    func saveTwoFactorSetting(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "twoFactorEnabled")
        
        // In a real app, you would enable/disable two-factor authentication on the server
        // This is just a placeholder
        if enabled {
            // Show instructions for setting up 2FA
            successMessage = "Two-factor authentication has been enabled."
            showingSuccessAlert = true
        }
    }
    
    func saveNotificationSetting(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "notifyOnLogin")
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
                successMessage = "Password reset email sent to \(email)"
                showingSuccessAlert = true
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
