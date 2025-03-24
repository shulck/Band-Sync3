import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @State private var enablePushNotifications = false
    @State private var upcomingEvents = false
    @State private var newMessages = false
    @State private var taskReminders = false
    @State private var isLoading = true
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Push Notifications", isOn: $enablePushNotifications)
                    .onChange(of: enablePushNotifications) { newValue in
                        if newValue {
                            requestNotificationPermission()
                        } else {
                            saveNotificationSettings()
                        }
                    }
            }
            
            if enablePushNotifications {
                Section(header: Text("Notification Types")) {
                    Toggle("Upcoming Events", isOn: $upcomingEvents)
                        .onChange(of: upcomingEvents) { _ in
                            saveNotificationSettings()
                        }
                    
                    Toggle("New Messages", isOn: $newMessages)
                        .onChange(of: newMessages) { _ in
                            saveNotificationSettings()
                        }
                    
                    Toggle("Task Reminders", isOn: $taskReminders)
                        .onChange(of: taskReminders) { _ in
                            saveNotificationSettings()
                        }
                }
                
                Section(header: Text("Info")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("You can manage notification permissions in the iOS Settings app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button("Open Notification Settings") {
                        openSystemNotificationSettings()
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear(perform: loadNotificationSettings)
        .overlay(
            Group {
                if isLoading {
                    ProgressView()
                        .background(Color.white.opacity(0.7))
                }
            }
        )
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
    }
    
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
                
                self.isLoading = false
            }
        }
    }
    
    func requestNotificationPermission() {
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
        
        // In a real app, you would also update these settings on your server
        // or in Firebase to control what notifications to send to this device
    }
    
    func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
