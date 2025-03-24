import SwiftUI
import MessageUI

struct HelpCenterView: View {
    @State private var isShowingMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var isMailViewPresented = false
    @State private var showingEmailAlert = false
    
    var helpTopics = [
        "Getting Started",
        "Managing Events",
        "Working with Setlists",
        "Financial Management",
        "Account Settings",
        "Group Management",
        "Privacy & Security"
    ]
    
    var body: some View {
        List {
            Section(header: Text("Help Topics")) {
                ForEach(helpTopics, id: \.self) { topic in
                    NavigationLink(destination: HelpTopicDetailView(topic: topic)) {
                        HStack {
                            Image(systemName: iconForTopic(topic))
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text(topic)
                        }
                    }
                }
            }
            
            Section(header: Text("Contact Support")) {
                Button(action: {
                    if MFMailComposeViewController.canSendMail() {
                        isShowingMailView = true
                    } else {
                        showingEmailAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Email Support")
                    }
                }
                
                Link(destination: URL(string: "https://bandsync.example.com/support")!) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Visit Support Website")
                            .foregroundColor(.primary)
                    }
                }
                
                Link(destination: URL(string: "https://twitter.com/bandsync")!) {
                    HStack {
                        Image(systemName: "bubble.left")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Twitter Support")
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Section(header: Text("App Info")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (Build 1)")
                        .foregroundColor(.secondary)
                }
            }
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

struct HelpTopicDetailView: View {
    var topic: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(topic)
                    .font(.largeTitle)
                    .bold()
                    .padding()
                
                // Different content based on topic
                contentForTopic
                
                Spacer()
            }
            .padding()
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
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Welcome to BandSync", icon: "hand.wave") {
                Text("BandSync helps you manage your band's activities, events, setlists, and finances in one place.")
            }
            
            HelpSection(title: "Creating or Joining a Group", icon: "person.3") {
                Text("When you register, you can either create a new group (becoming its admin) or join an existing group using an invite code.")
            }
            
            HelpSection(title: "Navigating the App", icon: "arrow.left.and.right") {
                Text("Use the bottom tabs to navigate between Calendar, Setlists, Chats, Contacts, and More options.")
            }
            
            HelpSection(title: "Next Steps", icon: "arrow.right") {
                Text("Start by creating events in your calendar, setting up setlists, and inviting other band members to join your group.")
            }
        }
    }
    
    var eventsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Creating Events", icon: "calendar.badge.plus") {
                Text("Tap the + button in the Calendar tab to add a new event. You can specify details like venue, time, and type of event.")
            }
            
            HelpSection(title: "Event Types", icon: "list.bullet") {
                Text("BandSync supports various event types: Concerts, Rehearsals, Meetings, Interviews, and more.")
            }
            
            HelpSection(title: "Managing Event Details", icon: "pencil") {
                Text("Each event can include details about the venue, organizer contacts, hotel information, and a schedule for the day.")
            }
            
            HelpSection(title: "Assigning Setlists", icon: "music.note.list") {
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
