import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var registrationSuccess = false
    @State private var passwordStrength: PasswordStrength = .empty
    
    // Registration type selection
    @State private var registrationType = RegistrationType.createGroup
    @State private var groupCode = ""
    @State private var groupName = ""
    @State private var isCheckingGroupCode = false
    @State private var groupCodeStatus: GroupCodeStatus = .notChecked
    
    enum RegistrationType: String, CaseIterable, Identifiable {
        case createGroup = "Create New Group"
        case joinGroup = "Join Existing Group"
        
        var id: String { self.rawValue }
    }
    
    enum GroupCodeStatus {
        case notChecked
        case valid
        case invalid
        case checking
    }
    
    enum PasswordStrength: Int {
        case empty = 0
        case weak = 1
        case medium = 2
        case strong = 3
        
        var color: Color {
            switch self {
            case .empty: return .gray
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }
        
        var label: String {
            switch self {
            case .empty: return "Enter password"
            case .weak: return "Weak password"
            case .medium: return "Medium password"
            case .strong: return "Strong password"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Registration")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                // Basic User Information Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("User Information")
                        .font(.headline)
                        .padding(.leading)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .padding(.horizontal)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: password) { newValue in
                            passwordStrength = checkPasswordStrength(newValue)
                        }
                    
                    // Password strength indicator
                    HStack {
                        Text(passwordStrength.label)
                            .font(.caption)
                            .foregroundColor(passwordStrength.color)
                        
                        Spacer()
                        
                        ForEach(0..<3) { index in
                            Rectangle()
                                .fill(index < passwordStrength.rawValue ? passwordStrength.color : Color.gray.opacity(0.3))
                                .frame(width: 20, height: 4)
                        }
                    }
                    .padding(.horizontal)
                        
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Registration Type Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("Registration Type")
                        .font(.headline)
                        .padding(.leading)
                    
                    Picker("Registration Type", selection: $registrationType) {
                        ForEach(RegistrationType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Conditional fields based on registration type
                    if registrationType == .createGroup {
                        VStack(alignment: .leading) {
                            Text("You will be the administrator of this group")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading)
                            
                            TextField("Group Name", text: $groupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Text("Enter the code provided by your group administrator")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading)
                            
                            HStack {
                                TextField("Group Code", text: $groupCode)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: groupCode) { _ in
                                        // Reset status when code changes
                                        if groupCodeStatus != .notChecked {
                                            groupCodeStatus = .notChecked
                                        }
                                    }
                                
                                Button(action: checkGroupCode) {
                                    if groupCodeStatus == .checking {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Text("Verify")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .disabled(groupCode.isEmpty || groupCodeStatus == .checking)
                            }
                            .padding(.horizontal)
                            
                            // Group code status message
                            switch groupCodeStatus {
                            case .valid:
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Valid group code")
                                        .foregroundColor(.green)
                                }
                                .padding(.leading)
                            case .invalid:
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Invalid group code")
                                        .foregroundColor(.red)
                                }
                                .padding(.leading)
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(.vertical)

                // Error and success messages
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if registrationSuccess {
                    Text("Registration successful! You are now logged in.")
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Register button
                Button(action: register) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Register")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid && !isLoading ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                
                // Cancel button
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue)
                .padding(.bottom)
            }
            .padding()
        }
        .disabled(registrationSuccess)
    }
    
    private var isFormValid: Bool {
        let basicInfoValid = !email.isEmpty &&
               !name.isEmpty &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 6 &&
               email.contains("@") &&
               passwordStrength != .weak
        
        if registrationType == .createGroup {
            return basicInfoValid && !groupName.isEmpty
        } else {
            return basicInfoValid && groupCodeStatus == .valid
        }
    }
    private func checkPasswordStrength(_ password: String) -> PasswordStrength {
        if password.isEmpty { return .empty }
        
        // Basic password strength check
        var score = 0
        
        // Length check
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // Complexity checks
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChars = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        if hasUppercase && hasLowercase { score += 1 }
        if hasNumbers { score += 1 }
        if hasSpecialChars { score += 1 }
        
        // Convert score to strength
        switch score {
        case 0...1: return .weak
        case 2...3: return .medium
        default: return .strong
        }
    }
    func checkGroupCode() {
        guard !groupCode.isEmpty else {
            print("Group code is empty")
            return
        }
        
        groupCodeStatus = .checking
        isCheckingGroupCode = true
        
        let db = Firestore.firestore()
        db.collection("groups").whereField("code", isEqualTo: groupCode).getDocuments { snapshot, error in
            isCheckingGroupCode = false
            
            if let error = error {
                print("Error checking group code: \(error.localizedDescription)")
                groupCodeStatus = .invalid
                return
            }
            
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                groupCodeStatus = .valid
                print("Group code is valid")
            } else {
                groupCodeStatus = .invalid
                print("Group code is invalid")
            }
        }
    }
    func register() {
        guard isFormValid else {
            errorMessage = "Please check your inputs and try again."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            } else if let user = result?.user {
                if registrationType == .createGroup {
                    createNewGroup(user: user)
                } else {
                    joinExistingGroup(user: user)
                }
            }
        }
    }
    
    func createNewGroup(user: User) {
        let db = Firestore.firestore()
        
        // Generate unique group code
        let groupCode = generateGroupCode()
        
        // Create group document
        let groupRef = db.collection("groups").document()
        let groupData: [String: Any] = [
            "name": groupName,
            "code": groupCode,
            "createdBy": user.uid,
            "createdAt": FieldValue.serverTimestamp(),
            "members": [user.uid]
        ]
        
        groupRef.setData(groupData) { error in
            if let error = error {
                isLoading = false
                errorMessage = "Error creating group: \(error.localizedDescription)"
                return
            }
            
            // Create user document with Admin role
            let userData: [String: Any] = [
                "email": user.email ?? "",
                "name": name,
                "role": "Admin",
                "groupId": groupRef.documentID,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            db.collection("users").document(user.uid).setData(userData) { error in
                isLoading = false
                
                if let error = error {
                    errorMessage = "Error saving user data: \(error.localizedDescription)"
                } else {
                    // Update Firebase Auth display name
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = name
                    changeRequest.commitChanges { _ in }
                    
                    // Success
                    registrationSuccess = true
                    
                    // Auto login
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isLoggedIn = true
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    func joinExistingGroup(user: User) {
        let db = Firestore.firestore()
        
        // Find group by code
        db.collection("groups").whereField("code", isEqualTo: groupCode).getDocuments { snapshot, error in
            if let error = error {
                isLoading = false
                errorMessage = "Error finding group: \(error.localizedDescription)"
                return
            }
            
            guard let document = snapshot?.documents.first else {
                isLoading = false
                errorMessage = "Group not found"
                return
            }
            
            let groupId = document.documentID
            
            // Update group to add user as pending member
            let groupRef = db.collection("groups").document(groupId)
            groupRef.updateData([
                "pendingMembers": FieldValue.arrayUnion([user.uid])
            ]) { error in
                if let error = error {
                    isLoading = false
                    errorMessage = "Error joining group: \(error.localizedDescription)"
                    return
                }
                
                // Create user document with Pending role
                let userData: [String: Any] = [
                    "email": user.email ?? "",
                    "name": name,
                    "role": "Pending",
                    "groupId": groupId,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                db.collection("users").document(user.uid).setData(userData) { error in
                    isLoading = false
                    
                    if let error = error {
                        errorMessage = "Error saving user data: \(error.localizedDescription)"
                    } else {
                        // Update Firebase Auth display name
                        let changeRequest = user.createProfileChangeRequest()
                        changeRequest.displayName = name
                        changeRequest.commitChanges { _ in }
                        
                        // Success
                        registrationSuccess = true
                        
                        // Auto login
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isLoggedIn = true
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // Generate a random 6-character group code
    func generateGroupCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed similar looking characters
        return String((0..<6).map{ _ in letters.randomElement()! })
    }
}
