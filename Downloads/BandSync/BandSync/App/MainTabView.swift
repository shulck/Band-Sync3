import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    var userRole: String
    var groupId: String
    var groupName: String
    
    @State private var showGroupInfo = false
    
    var body: some View {
        TabView {
            CalendarView()
                .tabItem {
                    Label(LocalizedStringKey("calendar"), systemImage: "calendar")
                }

            SetlistView()
                .tabItem {
                    Label(LocalizedStringKey("setlists"), systemImage: "music.note.list")
                }

            if userRole == "Admin" || userRole == "Manager" {
                FinancesView()
                    .tabItem {
                        Label(LocalizedStringKey("finances"), systemImage: "dollarsign.circle")
                    }
            }
            
            // Chats tab
            ChatListView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }

            ContactsView()
                .tabItem {
                    Label(LocalizedStringKey("contacts"), systemImage: "person.2.fill")
                }

            MoreView(groupName: groupName, groupId: groupId, userRole: userRole)
                .tabItem {
                    Label(LocalizedStringKey("more"), systemImage: "ellipsis.circle")
                }
        }
        .onAppear {
            // Show welcome message with group info on first launch
            if !UserDefaults.standard.bool(forKey: "hasSeenWelcome") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showGroupInfo = true
                    UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
                }
            }
        }
        .alert(isPresented: $showGroupInfo) {
            Alert(
                title: Text("Welcome to \(groupName)"),
                message: Text("You are logged in as \(userRole)"),
                dismissButton: .default(Text("Got it!"))
            )
        }
    }
}

// More view with improved error handling
struct MoreView: View {
    var groupName: String
    var groupId: String
    var userRole: String
    
    @State private var isLoggedOut = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("GROUP: \(groupName)")) {
                    NavigationLink(destination: ProfileView()) {
                        Label("Profile", systemImage: "person.circle")
                    }
                    
                    NavigationLink(destination: AccountSettingsView()) {
                        Label("Account Settings", systemImage: "gear")
                    }
                    
                    if userRole == "Admin" {
                        NavigationLink(destination: AdminPanelView()) {
                            Label("Group Management", systemImage: "person.3")
                        }
                    }
                }
                
                Section(header: Text("MANAGEMENT")) {
                    NavigationLink(destination: TasksView()) {
                        Label("Tasks", systemImage: "checkmark.circle")
                    }
                }
                
                Section(header: Text("APPLICATION")) {
                    NavigationLink(destination: NotificationsSettingsView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    
                    NavigationLink(destination: LanguageSettingsView()) {
                        Label("Language", systemImage: "globe")
                    }
                }
                
                Section(header: Text("SUPPORT")) {
                    NavigationLink(destination: HelpCenterView()) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                    
                    Button(action: logout) {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                // Only show group code if user is admin and groupId is valid
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
            .navigationTitle("More")
            .background(
                NavigationLink(
                    destination: ContentView().navigationBarHidden(true),
                    isActive: $isLoggedOut
                ) {
                    EmptyView()
                }
            )
        }
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
            
            // Post notification for app to handle logout
            NotificationCenter.default.post(name: NSNotification.Name("LogoutUser"), object: nil)
            
            isLoggedOut = true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

// Group code view with improved error handling
struct GroupCodeView: View {
    let groupId: String
    @State private var groupCode: String = "Loading..."
    @State private var isSharePresented = false
    @State private var hasError = false
    
    var body: some View {
        HStack {
            Text(groupCode)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(6)
            
            Spacer()
            
            if !hasError {
                Button(action: {
                    isSharePresented = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear(perform: loadGroupCode)
        .sheet(isPresented: $isSharePresented) {
            ActivityViewController(activityItems: ["Join my BandSync group with code: \(groupCode)"])
        }
    }
    
    func loadGroupCode() {
        // Safety check for empty groupId
        guard !groupId.isEmpty else {
            hasError = true
            groupCode = "ERROR: No Group ID"
            return
        }
        
        let db = Firestore.firestore()
        db.collection("groups").document(groupId).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading group code: \(error.localizedDescription)")
                    hasError = true
                    groupCode = "ERROR: \(error.localizedDescription)"
                    return
                }
                
                if let document = document, document.exists, let data = document.data() {
                    groupCode = data["code"] as? String ?? "ERROR: No Code Found"
                } else {
                    hasError = true
                    groupCode = "ERROR: Group Not Found"
                }
            }
        }
    }
}

// Helper for sharing
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
