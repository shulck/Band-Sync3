import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isRegisterPresented = false
    @State private var isPhoneAuthPresented = false
    @State private var rememberMe = true
    @State private var showBiometricButton = false
    @State private var isLoading = false
    @State private var showForgotPassword = false
    
    private let biometricManager = BiometricAuthManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // App logo and title
            Text("BandSync")
                .font(.largeTitle)
                .bold()
                .padding(.top, 50)
            
            Text("Login")
                .font(.title)
                .bold()
                .padding(.bottom, 20)

            // Login form
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Toggle("Remember me", isOn: $rememberMe)
                    .padding(.horizontal)
            }
            
            // Error message display
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            // Sign In button
            Button(action: login) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            .disabled(isLoading || !isFormValid)
            
            // Forgot password
            Button(action: { showForgotPassword = true }) {
                Text("Forgot Password?")
                    .foregroundColor(.blue)
            }
            .padding(.top, 5)
            
            // Biometric login button
            if showBiometricButton {
                Button(action: biometricLogin) {
                    HStack {
                        Image(systemName: biometricManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text("Sign in with \(biometricManager.biometricType == .faceID ? "Face ID" : "Touch ID")")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // Additional options
            VStack(spacing: 15) {
                Button(action: {
                    isRegisterPresented = true
                }) {
                    Text("Register")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    isPhoneAuthPresented = true
                }) {
                    Text("Sign in with Phone Number")
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isRegisterPresented) {
            RegisterView(isLoggedIn: $isLoggedIn)
        }
        .sheet(isPresented: $isPhoneAuthPresented) {
            PhoneAuthView(isLoggedIn: $isLoggedIn)
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Link") {
                sendPasswordReset()
            }
        } message: {
            Text("Enter your email to receive a password reset link")
        }
        .onAppear {
            // Check for saved credentials on app start
            checkSavedCredentials()
            
            // Check for biometric availability
            showBiometricButton = biometricManager.biometricType != .none
        }
    }
    
    private var isFormValid: Bool {
        return !email.isEmpty && email.contains("@") && !password.isEmpty
    }

    func login() {
        // Reset error message
        errorMessage = ""
        
        // Validate fields
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password"
            return
        }
        
        isLoading = true
        
        // Firebase authentication
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            
            if let error = error {
                // More user-friendly error messages
                let errorCode = (error as NSError).code
                switch errorCode {
                case 17009: // Wrong password
                    errorMessage = "Incorrect password, please try again"
                case 17011: // Account doesn't exist
                    errorMessage = "Account not found. Please check your email or register"
                case 17010: // Network error
                    errorMessage = "Network error. Please check your connection"
                default:
                    errorMessage = "Login error: \(error.localizedDescription)"
                }
            } else if let user = result?.user {
                // Save credentials for future auto-login
                if rememberMe {
                    if biometricManager.biometricType != .none {
                        // If biometrics available, offer to enable it
                        saveBiometricCredentials(user: user)
                    } else {
                        // Otherwise just save email
                        UserDefaults.standard.set(email, forKey: "savedEmail")
                    }
                }
                isLoggedIn = true
            }
        }
    }
    
    func sendPasswordReset() {
        guard !email.isEmpty && email.contains("@") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                errorMessage = "Error: \(error.localizedDescription)"
            } else {
                errorMessage = "Password reset link sent to your email"
            }
        }
    }
    
    func biometricLogin() {
        BiometricAuthManager.shared.authenticate { result in
            switch result {
            case .success:
                // Get saved email for current user
                if let userID = UserDefaults.standard.string(forKey: "lastLoggedInUserID"),
                   let savedEmail = BiometricAuthManager.shared.getAuthCredentials(for: userID) {
                    
                    // Auto-fill email field
                    self.email = savedEmail
                    
                    // Check if there's an active Firebase session
                    if Auth.auth().currentUser != nil {
                        isLoggedIn = true
                    } else {
                        errorMessage = "Please enter your password to complete login"
                    }
                }
            case .failure(let error):
                switch error {
                case .userCancelled:
                    // User cancelled - don't show error
                    break
                case .biometryNotEnrolled:
                    errorMessage = "Biometric authentication not set up on this device"
                case .biometryLockout:
                    errorMessage = "Biometric authentication is locked. Please use your password"
                default:
                    errorMessage = "Biometric authentication failed"
                }
            }
        }
    }
    
    func saveBiometricCredentials(user: User) {
        // Save credentials for biometric login
        BiometricAuthManager.shared.setBiometricAuthEnabled(true, for: user.uid)
        BiometricAuthManager.shared.saveAuthCredentials(userID: user.uid, email: email)
        UserDefaults.standard.set(user.uid, forKey: "lastLoggedInUserID")
    }
    
    func checkSavedCredentials() {
        // Check if we have a saved user
        if let userID = UserDefaults.standard.string(forKey: "lastLoggedInUserID"),
           BiometricAuthManager.shared.isBiometricAuthEnabled(for: userID) {
            // If biometrics enabled for this user, show button
            showBiometricButton = true
        } else if let savedEmail = UserDefaults.standard.string(forKey: "savedEmail") {
            // Otherwise just fill in email
            email = savedEmail
        }
    }
}
