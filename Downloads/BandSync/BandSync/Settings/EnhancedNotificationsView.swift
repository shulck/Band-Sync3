import SwiftUI
import UserNotifications

struct EnhancedNotificationsView: View {
    @State private var enablePushNotifications = false
    @State private var upcomingEvents = false
    @State private var newMessages = false
    @State private var taskReminders = false
    @State private var isLoading = true
    @State private var showingPermissionAlert = false
    @State private var showPermissionSettings = false
    @State private var lastUpdated: Date? = nil
    @State private var isRefreshing = false
    @State private var savedSuccess = false
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Checking notification settings...")
                    .background(Color.white.opacity(0.7))
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Status Card
                        NotificationStatusCard(
                            enablePushNotifications: $enablePushNotifications,
                            onChange: requestNotificationPermission
                        )
                        
                        if enablePushNotifications {
                            // Notification Types
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Notification Types")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                NotificationTypeToggle(
                                    title: "Upcoming Events",
                                    description: "Get notified about events 24 hours before they start",
                                    isOn: $upcomingEvents,
                                    onChange: { saveNotificationSettings() }
                                )
                                
                                NotificationTypeToggle(
                                    title: "New Messages",
                                    description: "Get notified when someone sends you a message",
                                    isOn: $newMessages,
                                    onChange: { saveNotificationSettings() }
                                )
                                
                                NotificationTypeToggle(
                                    title: "Task Reminders",
                                    description: "Get notified about tasks assigned to you",
                                    isOn: $taskReminders,
                                    onChange: { saveNotificationSettings() }
                                )
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.horizontal)
                            
                            // System Settings Info
                            SystemSettingsInfoCard(
                                showSettings: $showPermissionSettings
                            )
                        } else {
                            // Permissions Required
                            NotificationPermissionsCard(
                                showSettings: $showPermissionSettings
                            )
                        }
                        
                        if let lastUpdated = lastUpdated {
                            Text("Last updated: \(formattedDate(lastUpdated))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        
                        if savedSuccess {
                            Text("Settings saved successfully!")
                                .foregroundColor(.green)
                                .padding()
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation {
                                            savedSuccess = false
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshSettings()
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear(perform: loadNotificationSettings)
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("Notification Permission Required"),
                message: Text("To receive notifications, please enable them in the Settings app."),
                primaryButton: .default(Text("Open Settings")) {
                    openSystemNotificationSettings()
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: showPermissionSettings) { newValue in
            if newValue {
                openSystemNotificationSettings()
                showPermissionSettings = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func loadNotificationSettings() {
        isLoading = true
        
        // Check if notifications are authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Only enable the toggle if notifications are authorized
                self.enablePushNotifications = (settings.authorizationStatus == .authorized)
                
                // Load saved settings
                self.upcomingEvents = UserDefaults.standard.bool(forKey: "notifyUpcomingEvents")
                self.newMessages = UserDefaults.standard.bool(forKey: "notifyNewMessages")
                self.taskReminders = UserDefaults.standard.bool(forKey: "notifyTaskReminders")
                
                if let lastUpdated = UserDefaults.standard.object(forKey: "notificationSettingsLastUpdated") as? Date {
                    self.lastUpdated = lastUpdated
                }
                
                self.isLoading = false
            }
        }
    }
    
    func requestNotificationPermission() {
        if enablePushNotifications {
            // User trying to turn off notifications, just save settings
            saveNotificationSettings()
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.enablePushNotifications = true
                    self.saveNotificationSettings()
                } else {
                    self.enablePushNotifications = false
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    func saveNotificationSettings() {
        UserDefaults.standard.set(enablePushNotifications, forKey: "notifyPushEnabled")
        UserDefaults.standard.set(upcomingEvents, forKey: "notifyUpcomingEvents")
        UserDefaults.standard.set(newMessages, forKey: "notifyNewMessages")
        UserDefaults.standard.set(taskReminders, forKey: "notifyTaskReminders")
        
        let now = Date()
        UserDefaults.standard.set(now, forKey: "notificationSettingsLastUpdated")
        lastUpdated = now
        
        // Show success message briefly
        withAnimation {
            savedSuccess = true
        }
        
        // Register for notifications based on settings
        if enablePushNotifications {
            registerNotificationCategories()
        }
    }
    
    func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func refreshSettings() async {
        isRefreshing = true
        
        return await withCheckedContinuation { continuation in
            loadNotificationSettings()
            
            // Simulate a brief loading period for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isRefreshing = false
                continuation.resume()
            }
        }
    }
    
    func registerNotificationCategories() {
        // Register categories for different types of notifications
        let center = UNUserNotificationCenter.current()
        
        // Create actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Details",
            options: .foreground
        )
        
        let markAsReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark as Read",
            options: .authenticationRequired
        )
        
        // Create event category
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_NOTIFICATION",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Create message category
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE_NOTIFICATION",
            actions: [viewAction, markAsReadAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Create task category
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_NOTIFICATION",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        center.setNotificationCategories([eventCategory, messageCategory, taskCategory])
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Components

struct NotificationStatusCard: View {
    @Binding var enablePushNotifications: Bool
    var onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("Push Notifications")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $enablePushNotifications)
                    .onChange(of: enablePushNotifications) { _ in
                        onChange()
                    }
            }
            
            Text(enablePushNotifications ?
                "You will receive push notifications based on your preferences" :
                "Enable push notifications to stay updated with your band's activities")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct NotificationTypeToggle: View {
    var title: String
    var description: String
    @Binding var isOn: Bool
    var onChange: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .onChange(of: isOn) { _ in
                    onChange()
                }
        }
        .padding(.vertical, 4)
    }
}

struct SystemSettingsInfoCard: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text("System Settings")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            Text("You can manage notification permissions in the iOS Settings app.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Open Notification Settings") {
                showSettings = true
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct NotificationPermissionsCard: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                
                Text("Permission Required")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            Text("Notifications are currently disabled for this app. Enable them in the iOS Settings to receive notifications about events, messages, and tasks.")
                .font(.callout)
                .foregroundColor(.secondary)
            
            Button("Open Notification Settings") {
                showSettings = true
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
