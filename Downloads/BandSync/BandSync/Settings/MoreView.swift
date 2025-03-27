import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MoreView: View {
    var groupName: String
    var groupId: String
    var userRole: String
    
    @State private var isLoggedOut = false
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        // Обратите внимание, что здесь нет NavigationView,
        // поскольку он уже есть в MainTabView
        List {
            // MARK: - Group Section
            Section(header: Text("GROUP: \(groupName)")) {
                NavigationLink(destination: ProfileViewWrapper()) {
                    MoreMenuRow(icon: "person.circle", title: "Profile")
                }
                
                NavigationLink(destination: AccountSettingsViewWrapper()) {
                    MoreMenuRow(icon: "gear", title: "Account Settings")
                }
                
                if userRole == "Admin" {
                    NavigationLink(destination: AdminPanelViewWrapper()) {
                        MoreMenuRow(icon: "person.3", title: "Group Management")
                    }
                }
            }
            
            // MARK: - Management Section
            Section(header: Text("MANAGEMENT")) {
                NavigationLink(destination: TasksViewWrapper()) {
                    MoreMenuRow(icon: "checkmark.circle", title: "Tasks")
                }
            }
            
            // MARK: - Application Section
            Section(header: Text("APPLICATION")) {
                NavigationLink(destination: NotificationsSettingsViewWrapper()) {
                    MoreMenuRow(icon: "bell", title: "Notifications")
                }
                
                NavigationLink(destination: AppearanceSettingsViewWrapper()) {
                    MoreMenuRow(icon: "paintbrush", title: "Appearance")
                }
                
                NavigationLink(destination: LanguageSettingsViewWrapper()) {
                    MoreMenuRow(icon: "globe", title: "Language")
                }
            }
            
            // MARK: - Support Section
            Section(header: Text("SUPPORT")) {
                NavigationLink(destination: HelpCenterViewWrapper()) {
                    MoreMenuRow(icon: "questionmark.circle", title: "Help Center")
                }
                
                NavigationLink(destination: AboutViewWrapper()) {
                    MoreMenuRow(icon: "info.circle", title: "About")
                }
                
                Button(action: {
                    showLogoutConfirmation = true
                }) {
                    MoreMenuRow(icon: "rectangle.portrait.and.arrow.right", title: "Logout", color: .red)
                }
            }
            
            // MARK: - Group Code Section (Only visible for admins)
            if userRole == "Admin" && !groupId.isEmpty {
                Section(header: Text("GROUP INFORMATION")) {
                    VStack(alignment: .leading) {
                        Text("Group Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        GroupCodeView(groupId: groupId)
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .background(
            NavigationLink(
                destination: ContentView().navigationBarHidden(true),
                isActive: $isLoggedOut
            ) {
                EmptyView()
            }
        )
        .alert(isPresented: $showLogoutConfirmation) {
            Alert(
                title: Text("Logout"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Logout")) {
                    logout()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Actions
    
    func logout() {
        do {
            try Auth.auth().signOut()
            
            // Clear any cached user data
            UserDefaults.standard.removeObject(forKey: "savedEmail")
            
            // Post notification for app to handle logout
            NotificationCenter.default.post(name: NSNotification.Name("LogoutUser"), object: nil)
            
            isLoggedOut = true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Components

// Row component for menu items
struct MoreMenuRow: View {
    var icon: String
    var title: String
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(title)
                .foregroundColor(color == .blue ? .primary : color)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// Group code component with improved error handling and UX
struct GroupCodeView: View {
    let groupId: String
    @State private var groupCode: String = ""
    @State private var isLoading = true
    @State private var isSharePresented = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .frame(height: 40)
            } else if hasError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error loading code")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Retry") {
                        loadGroupCode()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                Text(groupCode)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(6)
                
                Spacer()
                
                Button(action: {
                    isSharePresented = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                .disabled(hasError)
            }
        }
        .onAppear(perform: loadGroupCode)
        .sheet(isPresented: $isSharePresented) {
            ActivityViewController(items: ["Join my BandSync group with code: \(groupCode)"])
        }
    }
    
    func loadGroupCode() {
        isLoading = true
        hasError = false
        errorMessage = ""
        
        // Safety check for empty groupId
        guard !groupId.isEmpty else {
            hasError = true
            errorMessage = "No Group ID provided"
            isLoading = false
            groupCode = "ERROR"
            return
        }
        
        let db = Firestore.firestore()
        db.collection("groups").document(groupId).getDocument { document, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    hasError = true
                    errorMessage = error.localizedDescription
                    groupCode = "ERROR"
                    return
                }
                
                if let document = document, document.exists, let data = document.data() {
                    if let code = data["code"] as? String {
                        groupCode = code
                    } else {
                        hasError = true
                        errorMessage = "Group code not found in document"
                        groupCode = "ERROR"
                    }
                } else {
                    hasError = true
                    errorMessage = "Group document not found"
                    groupCode = "ERROR"
                }
            }
        }
    }
}

// Helper for sharing
struct ActivityViewController: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View Wrappers
// Эти обертки обеспечивают правильные заголовки для экранов

struct ProfileViewWrapper: View {
    var body: some View {
        EnhancedProfileView()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct AccountSettingsViewWrapper: View {
    var body: some View {
        EnhancedAccountSettingsView()
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct AdminPanelViewWrapper: View {
    var body: some View {
        AdminPanelView()
            .navigationTitle("Group Management")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct TasksViewWrapper: View {
    var body: some View {
        TasksView()
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct NotificationsSettingsViewWrapper: View {
    var body: some View {
        EnhancedNotificationsView()
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct AppearanceSettingsViewWrapper: View {
    var body: some View {
        AppearanceSettingsView()
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct LanguageSettingsViewWrapper: View {
    var body: some View {
        LanguageSettingsView()
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct HelpCenterViewWrapper: View {
    var body: some View {
        HelpCenterView()
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct AboutViewWrapper: View {
    var body: some View {
        AboutView()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
    }
}
