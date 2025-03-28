import SwiftUI
import MessageUI

struct HelpCenterView: View {
    @State private var isShowingMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var isMailViewPresented = false
    @State private var showingEmailAlert = false
    @State private var searchText = ""
    
    var helpTopics = [
        "Getting Started",
        "Managing Events",
        "Working with Setlists",
        "Financial Management",
        "Account Settings",
        "Group Management",
        "Privacy & Security"
    ]
    
    var filteredTopics: [String] {
        if searchText.isEmpty {
            return helpTopics
        } else {
            return helpTopics.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Поиск
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search help topics", text: $searchText)
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Содержимое списка
            List {
                Section {
                    ForEach(filteredTopics, id: \.self) { topic in
                        NavigationLink(destination: EnhancedHelpTopicDetailView(topic: topic)) {
                            HelpTopicRow(topic: topic)
                        }
                    }
                } header: {
                    SectionHeaderView(title: "HELP TOPICS", icon: "book.fill")
                }
                
                Section {
                    Button(action: {
                        if MFMailComposeViewController.canSendMail() {
                            isShowingMailView = true
                        } else {
                            showingEmailAlert = true
                        }
                    }) {
                        SupportOptionRow(
                            icon: "envelope.fill",
                            title: "Email Support",
                            description: "Contact our support team directly"
                        )
                    }
                    
                    Link(destination: URL(string: "https://bandsync.example.com/support")!) {
                        SupportOptionRow(
                            icon: "globe",
                            title: "Visit Support Website",
                            description: "Find tutorials and FAQs online"
                        )
                    }
                    
                    Link(destination: URL(string: "https://twitter.com/bandsync")!) {
                        SupportOptionRow(
                            icon: "bubble.left.fill",
                            title: "Twitter Support",
                            description: "Connect with us on Twitter"
                        )
                    }
                } header: {
                    SectionHeaderView(title: "CONTACT SUPPORT", icon: "person.fill.questionmark")
                }
                
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    SectionHeaderView(title: "APP INFO", icon: "info.circle.fill")
                }
                
                // Заголовок с логотипом внизу
                Section {
                    VStack {
                        Image("AppIcon") // Замените на логотип приложения
                            .resizable()
                            .frame(width: 60, height: 60)
                            .cornerRadius(15)
                            .padding(.top, 8)
                        
                        Text("BandSync Support")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text("We're here to help")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Help Center")
        .sheet(isPresented: $isShowingMailView) {
            MailView(result: $mailResult, isShowing: $isMailViewPresented)
        }
        .alert(isPresented: $showingEmailAlert) {
            Alert(
                title: Text("Cannot Send Email"),
                message: Text("Your device is not configured to send emails. Please check your email settings or contact support through our website."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    func iconForTopic(_ topic: String) -> String {
        switch topic {
        case "Getting Started":
            return "flag"
        case "Managing Events":
            return "calendar"
        case "Working with Setlists":
            return "music.note.list"
        case "Financial Management":
            return "dollarsign.circle"
        case "Account Settings":
            return "person.crop.circle"
        case "Group Management":
            return "person.3"
        case "Privacy & Security":
            return "lock.shield"
        default:
            return "questionmark.circle"
        }
    }
}

struct HelpTopicRow: View {
    var topic: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconForTopic(topic))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Text(topic)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 8)
    }
    
    func iconForTopic(_ topic: String) -> String {
        switch topic {
        case "Getting Started":
            return "flag.fill"
        case "Managing Events":
            return "calendar"
        case "Working with Setlists":
            return "music.note.list"
        case "Financial Management":
            return "dollarsign.circle.fill"
        case "Account Settings":
            return "person.crop.circle.fill"
        case "Group Management":
            return "person.3.fill"
        case "Privacy & Security":
            return "lock.shield.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

struct SupportOptionRow: View {
    var icon: String
    var title: String
    var description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 8)
    }
}

struct EnhancedHelpTopicDetailView: View {
    var topic: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Главный заголовок
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: iconForTopic(topic))
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Help & Documentation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Содержимое темы
                contentForTopic
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(topic)
    }
    
    @ViewBuilder
    var contentForTopic: some View {
        switch topic {
        case "Getting Started":
            gettingStartedContent
        case "Managing Events":
            eventsContent
        case "Working with Setlists":
            setlistsContent
        case "Financial Management":
            financesContent
        case "Account Settings":
            accountContent
        case "Group Management":
            groupContent
        case "Privacy & Security":
            securityContent
        default:
            Text("Information about \(topic) will be available soon.")
        }
    }
    
    var gettingStartedContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            EnhancedHelpSection(title: "Welcome to BandSync", icon: "hand.wave") {
                Text("BandSync helps you manage your band's activities, events, setlists, and finances in one place.")
            }
            
            EnhancedHelpSection(title: "Creating or Joining a Group", icon: "person.3") {
                Text("When you register, you can either create a new group (becoming its admin) or join an existing group using an invite code.")
            }
            
            EnhancedHelpSection(title: "Navigating the App", icon: "arrow.left.and.right") {
                Text("Use the bottom tabs to navigate between Calendar, Setlists, Chats, Contacts, and More options.")
            }
            
            EnhancedHelpSection(title: "Next Steps", icon: "arrow.right") {
                Text("Start by creating events in your calendar, setting up setlists, and inviting other band members to join your group.")
            }
        }
    }
    
    var eventsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            EnhancedHelpSection(title: "Creating Events", icon: "calendar.badge.plus") {
                Text("Tap the + button in the Calendar tab to add a new event. You can specify details like venue, time, and type of event.")
            }
            
            EnhancedHelpSection(title: "Event Types", icon: "list.bullet") {
                Text("BandSync supports various event types: Concerts, Rehearsals, Meetings, Interviews, and more.")
            }
            
            EnhancedHelpSection(title: "Managing Event Details", icon: "pencil") {
                Text("Each event can include details about the venue, organizer contacts, hotel information, and a schedule for the day.")
            }
            
            EnhancedHelpSection(title: "Assigning Setlists", icon: "music.note.list") {
                Text("Connect your events to setlists to keep track of what songs you'll be performing.")
            }
        }
    }
    
    var setlistsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // (Similar pattern for setlists help content)
            Text("Setlists help content would go here.")
        }
    }
    
    var financesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // (Similar pattern for finances help content)
            Text("Finances help content would go here.")
        }
    }
    
    var accountContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // (Similar pattern for account help content)
            Text("Account settings help content would go here.")
        }
    }
    
    var groupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // (Similar pattern for group management help content)
            Text("Group management help content would go here.")
        }
    }
    
    var securityContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // (Similar pattern for security help content)
            Text("Security help content would go here.")
        }
    }
    
    func iconForTopic(_ topic: String) -> String {
        switch topic {
        case "Getting Started":
            return "flag.fill"
        case "Managing Events":
            return "calendar"
        case "Working with Setlists":
            return "music.note.list"
        case "Financial Management":
            return "dollarsign.circle.fill"
        case "Account Settings":
            return "person.crop.circle.fill"
        case "Group Management":
            return "person.3.fill"
        case "Privacy & Security":
            return "lock.shield.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

struct EnhancedHelpSection<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text(title)
                    .font(.headline)
            }
            
            content
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.leading, 48)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct HelpSection<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            content
                .padding(.leading, 30)
        }
        .padding(.vertical, 8)
    }
}

struct MailView: UIViewControllerRepresentable {
    @Binding var result: Result<MFMailComposeResult, Error>?
    @Binding var isShowing: Bool
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var result: Result<MFMailComposeResult, Error>?
        @Binding var isShowing: Bool
        
        init(result: Binding<Result<MFMailComposeResult, Error>?>, isShowing: Binding<Bool>) {
            _result = result
            _isShowing = isShowing
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                isShowing = false
            }
            
            if let error = error {
                self.result = .failure(error)
                return
            }
            self.result = .success(result)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(result: $result, isShowing: $isShowing)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["support@bandsync.example.com"])
        vc.setSubject("BandSync Support Request")
        vc.setMessageBody("Please describe your issue or question:", isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
