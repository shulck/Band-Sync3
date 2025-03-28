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
            Section {
                NavigationLink(destination: ProfileViewWrapper()) {
                    MoreMenuRow(icon: "person.circle.fill", title: "Profile")
                }
                
                NavigationLink(destination: AccountSettingsViewWrapper()) {
                    MoreMenuRow(icon: "gearshape.fill", title: "Account Settings")
                }
                
                if userRole == "Admin" {
                    NavigationLink(destination: AdminPanelViewWrapper()) {
                        MoreMenuRow(icon: "person.3.fill", title: "Group Management")
                    }
                }
            } header: {
                SectionHeaderView(title: "GROUP: \(groupName)")
            }
            
            // MARK: - Management Section
            Section {
                NavigationLink(destination: TasksViewWrapper()) {
                    MoreMenuRow(icon: "checkmark.circle.fill", title: "Tasks")
                }
            } header: {
                SectionHeaderView(title: "MANAGEMENT")
            }
            
            // MARK: - Application Section
            Section {
                NavigationLink(destination: NotificationsSettingsViewWrapper()) {
                    MoreMenuRow(icon: "bell.fill", title: "Notifications")
                }
                
                NavigationLink(destination: AppearanceSettingsViewWrapper()) {
                    MoreMenuRow(icon: "paintbrush.fill", title: "Appearance")
                }
                
                NavigationLink(destination: LanguageSettingsViewWrapper()) {
                    MoreMenuRow(icon: "globe", title: "Language")
                }
            } header: {
                SectionHeaderView(title: "APPLICATION")
            }
            
            // MARK: - Support Section
            Section {
                NavigationLink(destination: HelpCenterViewWrapper()) {
                    MoreMenuRow(icon: "questionmark.circle.fill", title: "Help Center")
                }
                
                NavigationLink(destination: AboutViewWrapper()) {
                    MoreMenuRow(icon: "info.circle.fill", title: "About")
                }
                
                Button(action: {
                    showLogoutConfirmation = true
                }) {
                    MoreMenuRow(icon: "rectangle.portrait.and.arrow.right.fill", title: "Logout", color: .red)
                }
            } header: {
                SectionHeaderView(title: "SUPPORT")
            }
            
            // MARK: - Group Code Section (Only visible for admins)
            if userRole == "Admin" && !groupId.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        EnhancedGroupCodeView(groupId: groupId)
                    }
                    .padding(.vertical, 4)
                } header: {
                    SectionHeaderView(title: "GROUP INFORMATION")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
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

// Enhanced section header design
struct SectionHeaderView: View {
    var title: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.bottom, 4)
        }
    }
}

// Row component for menu items with enhanced design
struct MoreMenuRow: View {
    var icon: String
    var title: String
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color == .blue ? .primary : color)
            
            Spacer()
            
            if color == .blue {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.vertical, 8)
    }
}

// Enhanced group code component with improved design
struct EnhancedGroupCodeView: View {
    let groupId: String
    @State private var groupCode: String = ""
    @State private var isLoading = true
    @State private var isSharePresented = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding()
                    Spacer()
                }
                .frame(height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else if hasError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Error loading code")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { loadGroupCode() }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                HStack {
                    Text(groupCode)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                    
                    Button(action: {
                        isSharePresented = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                    }
                    .disabled(hasError)
                }
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
