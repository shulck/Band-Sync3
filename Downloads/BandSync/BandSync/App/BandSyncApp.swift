import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage // Added Firebase Storage import
import UserNotifications

@main
struct BandSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var appReloadTrigger = UUID()

    let persistenceController = PersistenceController.shared

    init() {
        // Initialize notification service
        let _ = NotificationService.shared

        // Global observer for language change
        NotificationCenter.default.addObserver(
            forName: Notification.Name("LanguageChanged"),
            object: nil,
            queue: .main
        ) { _ in
            // This code will execute when language changes
            print("🌐 Language changed to: \(LocalizationManager.shared.currentLanguage.rawValue)")
        }

        // Observer for forced app reload
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceAppReload"),
            object: nil,
            queue: .main
        ) { [self] _ in
            // Changing this identifier will force SwiftUI to fully rebuild the app
            self.appReloadTrigger = UUID()
            print("🔄 Forced app reload")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(localizationManager)
                .id(appReloadTrigger) // Reload when ID changes
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("🔥 Firebase successfully initialized!")
        Firestore.firestore() // Initialize Firestore
        Storage.storage() // Initialize Firebase Storage

        // Configure notification center
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.setupNotificationActions()

        // Configure security
        configureSecuritySettings()

        return true
    }

    private func configureSecuritySettings() {
        // Configure security and data protection settings

        // 1. Configure Firebase authentication parameters
        let auth = Auth.auth()
        auth.settings?.isAppVerificationDisabledForTesting = false

        // 2. Configure Firestore security
        let db = Firestore.firestore()
        let settings = db.settings
        // Use the latest TLS version
        settings.isSSLEnabled = true
        db.settings = settings

        // 3. Log important security operations
        print("🔐 Security settings configured successfully")
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even if the app is in focus
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "VIEW_EVENT":
            // Open event details
            if let eventId = userInfo["eventId"] as? String {
                // Code for navigating to event details
                print("Opening event with ID: \(eventId)")
            }
        case "REMIND_LATER":
            // Remind later
            if let eventId = userInfo["eventId"] as? String,
               let eventTitle = userInfo["eventTitle"] as? String,
               let eventLocation = userInfo["eventLocation"] as? String {

                // Create a new notification in 30 minutes
                let content = UNMutableNotificationContent()
                content.title = "Reminder: \(eventTitle)"
                content.body = "Location: \(eventLocation)"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
                let request = UNNotificationRequest(identifier: "reminder-later-\n\(eventId)", content: content, trigger: trigger)

                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling reminder: \(error.localizedDescription)")
                    }
                }
            }
        default:
            // Handle standard tap
            if let eventId = userInfo["eventId"] as? String {
                print("Opening event with ID: \(eventId)")
            }
        }

        completionHandler()
    }
}
