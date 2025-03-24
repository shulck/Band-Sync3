import SwiftUI
import FirebaseAuth

struct PhoneAuthView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isLoggedIn: Bool
    
    @State private var phoneNumber = ""
    @State private var verificationID: String?
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var linkToExistingAccount = false
    @State private var isSuccess = false
    @State private var countryCode = "+1"
    
    // Available country codes
    let countryCodes = ["+1", "+44", "+380", "+49", "+33", "+39", "+34", "+81", "+86", "+91"]

    var body: some View {
        VStack {
            Text("Phone Verification")
                .font(.largeTitle)
                .bold()
                .padding()

            if isSuccess {
                // Success state
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.green)
                    
                    Text("Verification Successful!")
                        .font(.title)
                        .bold()
                    
                    Text("Your phone number has been verified and linked to your account.")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            } else if !isCodeSent {
                // Step 1: Enter phone number
                VStack(spacing: 20) {
                    Text("Enter your phone number to receive a verification code")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack {
                        // Country code picker
                        Menu {
                            ForEach(countryCodes, id: \.self) { code in
                                Button(code) {
                                    countryCode = code
                                }
                            }
                        } label: {
                            Text(countryCode)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: phoneNumber) { newValue in
                                // Format phone number as user types
                                phoneNumber = formatPhoneNumber(newValue)
                            }
                    }
                    .padding(.horizontal)
                    
                    // Example text
                    Text("Example: \(countryCode) 555-123-4567")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if Auth.auth().currentUser != nil {
                        Toggle("Link to my existing account", isOn: $linkToExistingAccount)
                            .padding(.horizontal)
                    }

                    Button(action: sendCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Send Code")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPhoneValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading || !isPhoneValid)
                    .padding(.horizontal)
                }
            } else {
                // Step 2: Enter verification code
                VStack(spacing: 20) {
                    Text("Enter the verification code sent to \(countryCode) \(phoneNumber)")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Code entry field
                    HStack(spacing: 10) {
                        ForEach(0..<6) { index in
                            CodeDigitField(index: index, code: $verificationCode)
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: verificationCode) { newValue in
                        // Automatically verify when all 6 digits are entered
                        if newValue.count == 6 && !isLoading {
                            verifyCode()
                        }
                    }

                    Button(action: verifyCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Verify Code")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(verificationCode.count == 6 && !isLoading ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading || verificationCode.count < 6)
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Go back to change phone number
                        isCodeSent = false
                    }) {
                        Text("Change Phone Number")
                            .foregroundColor(.blue)
                    }
                    
                    // Resend code option (after 30 seconds)
                    ResendCodeButton(onResend: sendCode)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            // Cancel button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .foregroundColor(.blue)
            }
            .padding()
        }
        .padding()
        .disabled(isLoading)
    }
    
    private var isPhoneValid: Bool {
        // Basic validation - number must be at least 10 digits
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        return digitsOnly.count >= 10
    }
    
    private func formatPhoneNumber(_ input: String) -> String {
        // Remove all non-digit characters
        let digitsOnly = input.filter { $0.isNumber }
        
        // Format based on US style (for simplicity)
        // Can be expanded to handle different country formats
        if digitsOnly.count <= 3 {
            return digitsOnly
        } else if digitsOnly.count <= 6 {
            let index = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            return "\(digitsOnly[..<index])-\(digitsOnly[index...])"
        } else {
            let index1 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            let index2 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 6)
            return "\(digitsOnly[..<index1])-\(digitsOnly[index1..<index2])-\(digitsOnly[index2...])"
        }
    }

    func sendCode() {
        isLoading = true
        errorMessage = ""
        
        // Format phone number
        let formattedNumber = "\(countryCode)\(phoneNumber.filter { $0.isNumber })"
        
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedNumber, uiDelegate: nil) { verificationID, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    // More user-friendly error messages
                    let nsError = error as NSError
                    switch nsError.code {
                    case 17010:
                        errorMessage = "Network error. Please check your connection."
                    case 17026:
                        errorMessage = "This phone number is invalid. Please check and try again."
                    case 17042:
                        errorMessage = "Too many requests. Please try again later."
                    default:
                        errorMessage = "Error: \(error.localizedDescription)"
                    }
                } else if let verificationID = verificationID {
                    self.verificationID = verificationID
                    isCodeSent = true
                    // Clear any existing verification code
                    verificationCode = ""
                }
            }
        }
    }

    func verifyCode() {
        isLoading = true
        errorMessage = ""
        
        guard let verificationID = verificationID else {
            errorMessage = "Error: No verification ID"
            isLoading = false
            return
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        // If user already logged in and wants to link number
        if let currentUser = Auth.auth().currentUser, linkToExistingAccount {
            currentUser.link(with: credential) { result, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        let nsError = error as NSError
                        switch nsError.code {
                        case 17044:
                            errorMessage = "Invalid verification code. Please try again."
                        case 17046:
                            errorMessage = "This phone number is already linked to another account."
                        default:
                            errorMessage = "Error: \(error.localizedDescription)"
                        }
                    } else {
                        // Successfully linked phone number to account
                        isSuccess = true
                    }
                }
            }
        } else {
            // If user not logged in, sign in with phone number
            Auth.auth().signIn(with: credential) { result, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        let nsError = error as NSError
                        switch nsError.code {
                        case 17044:
                            errorMessage = "Invalid verification code. Please try again."
                        default:
                            errorMessage = "Error: \(error.localizedDescription)"
                        }
                    } else {
                        // Successful phone authentication
                        isSuccess = true
                        
                        // If this is a new login, set flag
                        if !linkToExistingAccount {
                            isLoggedIn = true
                        }
                    }
                }
            }
        }
    }
}

// Single digit field for verification code
struct CodeDigitField: View {
    let index: Int
    @Binding var code: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            if code.count > index {
                let startIndex = code.index(code.startIndex, offsetBy: index)
                let endIndex = code.index(code.startIndex, offsetBy: index + 1)
                Text(String(code[startIndex..<endIndex]))
                    .font(.title)
                    .bold()
            }
            
            TextField("", text: $code)
                .frame(width: 0, height: 0)
                .opacity(0)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .onAppear {
                    // Set focus when this is the current digit to enter
                    if code.count == index {
                        isFocused = true
                    }
                }
                .onChange(of: code) { _ in
                    // Limit to 6 digits and numbers only
                    code = String(code.filter { $0.isNumber }.prefix(6))
                }
        }
        .frame(width: 45, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.blue : Color.gray, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
        )
        .onTapGesture {
            isFocused = true
        }
    }
}

// Button to resend code with countdown
struct ResendCodeButton: View {
    var onResend: () -> Void
    @State private var timeRemaining = 30
    @State private var canResend = false
    @State private var timer: Timer? = nil
    
    var body: some View {
        Button(action: {
            if canResend {
                onResend()
                startTimer()
            }
        }) {
            if canResend {
                Text("Resend Code")
                    .foregroundColor(.blue)
            } else {
                Text("Resend Code in \(timeRemaining)s")
                    .foregroundColor(.gray)
            }
        }
        .disabled(!canResend)
        .onAppear(perform: startTimer)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        canResend = false
        timeRemaining = 30
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                canResend = true
                timer?.invalidate()
                timer = nil
            }
        }
    }
}
