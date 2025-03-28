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
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoading {
                NotificationLoadingView(message: "Checking notification settings...")
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        EnhancedStatusCard(
                            enablePushNotifications: $enablePushNotifications,
                            onChange: requestNotificationPermission
                        )
                        
                        if enablePushNotifications {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    Text("Notification Types")
                                        .font(.headline)
                                        .bold()
                                }
                                .padding(.bottom, 4)
                                
                                EnhancedNotificationToggle(
                                    title: "Upcoming Events",
                                    description: "Get notified about events 24 hours before they start",
                                    icon: "calendar.badge.exclamationmark",
                                    isOn: $upcomingEvents,
                                    color: .blue,
                                    onChange: { saveNotificationSettings() }
                                )
                                
                                Divider()
                                
                                EnhancedNotificationToggle(
                                    title: "New Messages",
                                    description: "Get notified when someone sends you a message",
                                    icon: "message.fill",
                                    isOn: $newMessages,
                                    color: .green,
                                    onChange: { saveNotificationSettings() }
                                )
                                
                                Divider()
                                
                                EnhancedNotificationToggle(
                                    title: "Task Reminders",
                                    description: "Get notified about tasks assigned to you",
                                    icon: "checklist",
                                    isOn: $taskReminders,
                                    color: .orange,
                                    onChange: { saveNotificationSettings() }
                                )
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                            
                            EnhancedSystemSettingsCard(
                                showSettings: $showPermissionSettings
                            )
                        } else {
                            EnhancedPermissionsCard(
                                showSettings: $showPermissionSettings
                            )
                        }
                        
                        if let lastUpdated = lastUpdated {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                                
                                Text("Last updated: \(formattedDate(lastUpdated))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        
                        if savedSuccess {
                            SuccessMessageView(message: "Settings saved successfully!")
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
    
    func loadNotificationSettings() {
        isLoading = true
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.enablePushNotifications = (settings.authorizationStatus == .authorized)
                
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
        
        withAnimation {
            savedSuccess = true
        }
        
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isRefreshing = false
                continuation.resume()
            }
        }
    }
    
    func registerNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
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
        
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_NOTIFICATION",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE_NOTIFICATION",
            actions: [viewAction, markAsReadAction],
            intentIdentifiers: [],
            options: []
        )
        
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_NOTIFICATION",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([eventCategory, messageCategory, taskCategory])
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EnhancedStatusCard: View {
    @Binding var enablePushNotifications: Bool
    var onChange: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(enablePushNotifications ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: enablePushNotifications ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(enablePushNotifications ? .blue : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Push Notifications")
                        .font(.headline)
                        .bold()
                    
                    Text(enablePushNotifications ?
                        "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundColor(enablePushNotifications ? .green : .secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $enablePushNotifications)
                    .onChange(of: enablePushNotifications) { _ in
                        onChange()
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                    .scaleEffect(0.9)
            }
            
            Text(enablePushNotifications ?
                "You will receive push notifications based on your preferences below" :
                "Enable push notifications to stay updated with your band's activities")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

struct EnhancedNotificationToggle: View {
    var title: String
    var description: String
    var icon: String
    @Binding var isOn: Bool
    var color: Color
    var onChange: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isOn ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .onChange(of: isOn) { _ in
                    onChange()
                }
                .toggleStyle(SwitchToggleStyle(tint: color))
                .labelsHidden()
                .scaleEffect(0.85)
        }
        .padding(.vertical, 4)
    }
}

struct EnhancedSystemSettingsCard: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18, weight: .semibold))
                
                Text("System Settings")
                    .font(.headline)
                    .bold()
            }
            
            Text("You can manage notification permissions in the iOS Settings app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {
                showSettings = true
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Open Notification Settings")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

struct EnhancedPermissionsCard: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permission Required")
                        .font(.headline)
                        .bold()
                    
                    Text("Notifications are disabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Notifications are currently disabled for this app. Enable them in the iOS Settings to receive notifications about events, messages, and tasks.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            
            Button(action: {
                showSettings = true
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Open Notification Settings")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.orange.opacity(0.3), radius: 5, x: 0, y: 3)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

struct SuccessMessageView: View {
    var message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct NotificationLoadingView: View {
    var message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: 360))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: UUID()
                    )
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Please wait")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
    }
}
