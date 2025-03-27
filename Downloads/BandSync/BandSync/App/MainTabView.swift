import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    var userRole: String
    var groupId: String
    var groupName: String
    
    @State private var showGroupInfo = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Calendar Tab с NavigationStack
            NavigationStack {
                CalendarView()
                    .navigationTitle("Calendar")
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(0)

            // Setlist Tab
            NavigationStack {
                SetlistView()
                    .navigationTitle("Setlists")
            }
            .tabItem {
                Label("Setlists", systemImage: "music.note.list")
            }
            .tag(1)

            // Finances Tab (только для Admin или Manager)
            if userRole == "Admin" || userRole == "Manager" {
                NavigationStack {
                    FinancesView()
                        .navigationTitle("Finances")
                }
                .tabItem {
                    Label("Finances", systemImage: "dollarsign.circle")
                }
                .tag(2)
            }
            
            // Chats Tab
            NavigationStack {
                ChatListView()
                    .navigationTitle("Chats")
            }
            .tabItem {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(3)

            // Contacts Tab
            NavigationStack {
                ContactsView()
                    .navigationTitle("Contacts")
            }
            .tabItem {
                Label("Contacts", systemImage: "person.2.fill")
            }
            .tag(4)

            // More Tab с NavigationStack
            NavigationStack {
                MoreView(groupName: groupName, groupId: groupId, userRole: userRole)
                    .navigationTitle("More")
            }
            .tabItem {
                Label("More", systemImage: "ellipsis.circle")
            }
            .tag(5)
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
