import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var userRole: String = "Loading..."
    @State private var isLoggedIn = false
    @State private var refreshUI = false  // Flag to force UI refresh
    @State private var groupId: String = ""
    @State private var groupName: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if isLoggedIn {
                MainTabView(userRole: userRole, groupId: groupId, groupName: groupName)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear {
            checkAuth()
            setupObservers()
        }
        .id(refreshUI)  // Use flag to force refresh when it changes
    }
    
    // Loading view
    var loadingView: some View {
        VStack {
            ProgressView("Loading...")
            Text("Please wait")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }
    
    // Error view
    func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 70))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                errorMessage = nil
                isLoading = true
                checkAuth()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("Login Screen") {
                errorMessage = nil
                isLoading = false
                isLoggedIn = false
            }
            .padding(.top, 10)
        }
        .padding()
    }

    func checkAuth() {
        isLoading = true
        errorMessage = nil
        
        if let user = Auth.auth().currentUser {
            isLoggedIn = true
            fetchUserData(user: user)
        } else {
            isLoading = false
            isLoggedIn = false
            userRole = "Unknown"
            groupId = ""
            groupName = ""
        }
    }

    func fetchUserData(user: User) {
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                isLoading = false
                errorMessage = "Error fetching user data: \(error.localizedDescription)"
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                isLoading = false
                errorMessage = "User account exists but profile data is missing"
                return
            }
            
            // Get user role
            self.userRole = data["role"] as? String ?? "Unknown"
            
            // Get group ID
            if let gId = data["groupId"] as? String, !gId.isEmpty {
                self.groupId = gId
                
                // Fetch group name
                db.collection("groups").document(gId).getDocument { groupDoc, error in
                    isLoading = false
                    
                    if let error = error {
                        print("Error fetching group: \(error.localizedDescription)")
                        self.groupName = "Unknown Group"
                        return
                    }
                    
                    if let groupDoc = groupDoc, groupDoc.exists, let groupData = groupDoc.data() {
                        self.groupName = groupData["name"] as? String ?? "Unknown Group"
                    } else {
                        self.groupName = "Unknown Group"
                    }
                }
            } else {
                // Handle case where user has no group
                isLoading = false
                self.groupId = ""
                self.groupName = "No Group"
            }
        }
    }
    
    func setupObservers() {
        // Observer for language changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("LanguageChanged"),
            object: nil,
            queue: .main
        ) { _ in
            // Force UI update on language change
            self.refreshUI.toggle()
        }
        
        // Observer for user logout
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LogoutUser"),
            object: nil,
            queue: .main
        ) { _ in
            self.isLoggedIn = false
            self.userRole = "Unknown"
            self.groupId = ""
            self.groupName = ""
        }
    }
}
