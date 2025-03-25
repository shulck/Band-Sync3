import SwiftUI
import FirebaseFirestore
import MapKit

struct EventDetailView: View {
    let event: Event
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMap = false
    @State private var showingEdit = false
    @State private var showingSetlistPicker = false
    @State private var showingNotificationSettings = false
    @State private var selectedReminderTime: ReminderTime = .oneHour
    @State private var notificationsEnabled = false
    @State private var eventSetlist: [String] = []
    
    private let notificationService = NotificationService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовок события
                VStack(alignment: .leading) {
                    Text(event.title)
                        .font(.largeTitle).bold()
                    Text("\(event.icon) \(event.type) • \(event.status)")
                        .foregroundColor(.secondary)
                    Text(event.date.formatted(date: .long, time: .shortened))
                        .foregroundColor(.blue)
                }
                
                Divider()
                
                // Секция местоположения
                VStack(alignment: .leading, spacing: 4) {
                    Label("Location", systemImage: "mappin.and.ellipse")
                        .font(.headline)
                    Text(event.location).foregroundColor(.secondary)
                    
                    Button(action: {
                        showingMap.toggle()
                    }) {
                        Label(showingMap ? "Hide Map" : "Show on Map",
                              systemImage: showingMap ? "map.fill" : "map")
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
                
                // Информация об организаторе
                if eventNeedsOrganizer(event.type) || !event.organizer.name.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Organizer", systemImage: "person")
                            .font(.headline)
                        
                        if !event.organizer.name.isEmpty {
                            Text(event.organizer.name)
                                .foregroundColor(.secondary)
                        }
                        
                        if !event.organizer.phone.isEmpty {
                            Button(action: {
                                callPhoneNumber(event.organizer.phone)
                            }) {
                                Label(event.organizer.phone, systemImage: "phone")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if !event.organizer.email.isEmpty {
                            Button(action: {
                                sendEmail(event.organizer.email)
                            }) {
                                Label(event.organizer.email, systemImage: "envelope")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Информация о координаторе
                if eventNeedsCoordinator(event.type) || !event.coordinator.name.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Coordinator", systemImage: "person")
                            .font(.headline)
                        
                        if !event.coordinator.name.isEmpty {
                            Text(event.coordinator.name)
                                .foregroundColor(.secondary)
                        }
                        
                        if !event.coordinator.phone.isEmpty {
                            Button(action: {
                                callPhoneNumber(event.coordinator.phone)
                            }) {
                                Label(event.coordinator.phone, systemImage: "phone")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if !event.coordinator.email.isEmpty {
                            Button(action: {
                                sendEmail(event.coordinator.email)
                            }) {
                                Label(event.coordinator.email, systemImage: "envelope")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Информация о гостинице
                if eventNeedsHotel(event.type) && (!event.hotel.address.isEmpty || !event.hotel.checkIn.isEmpty) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Hotel", systemImage: "bed.double")
                            .font(.headline)
                        
                        if !event.hotel.address.isEmpty {
                            Text("Address: \(event.hotel.address)")
                                .foregroundColor(.secondary)
                        }
                        
                        if !event.hotel.checkIn.isEmpty {
                            Text("Check-in: \(event.hotel.checkIn)")
                                .foregroundColor(.secondary)
                        }
                        
                        if !event.hotel.checkOut.isEmpty {
                            Text("Check-out: \(event.hotel.checkOut)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Информация о гонораре
                if eventNeedsFee(event.type) && !event.fee.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Fee: \(event.fee)", systemImage: "dollarsign.circle")
                            .font(.headline)
                    }
                }
                
                // Сетлист
                if eventNeedsSetlist(event.type) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Setlist", systemImage: "music.note.list")
                            .font(.headline)
                        
                        if eventSetlist.isEmpty {
                            Button(action: {
                                showingSetlistPicker = true
                            }) {
                                Label("Connect Setlist", systemImage: "music.note.list")
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        } else {
                            ForEach(eventSetlist, id: \.self) { song in
                                HStack {
                                    Text("🎵")
                                    Text(song)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            
                            Button(action: {
                                showingSetlistPicker = true
                            }) {
                                Label("Change Setlist", systemImage: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Расписание дня
                if !event.schedule.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Schedule", systemImage: "calendar.badge.clock")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(event.schedule) { item in
                                HStack(alignment: .top) {
                                    Text(item.time)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Text(item.activity)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // Заметки
                if !event.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                        
                        Text(event.notes)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                
                // Секция настройки уведомлений
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notifications", systemImage: "bell")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            if notificationsEnabled {
                                Text("Event reminder set")
                                    .foregroundColor(.green)
                            } else {
                                Text("No reminder set")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingNotificationSettings = true
                        }) {
                            Text("Set Reminder")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
                
                if showingMap {
                    MapLocationView(address: event.location)
                        .frame(height: 250)
                        .cornerRadius(12)
                        .padding(.vertical, 4)
                }
                // Финансовая секция
                NavigationLink(destination: EventFinancesView(event: event)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Финансы", systemImage: "dollarsign.circle")
                            .font(.headline)
                        
                        Text("Просмотр доходов и расходов, связанных с событием")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                // Кнопки действий
                HStack {
                    Button(action: {
                        showingEdit = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button(action: {
                        shareEvent()
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: deleteEvent) {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingSetlistPicker) {
            SetlistPickerView(selectedSetlist: $eventSetlist)
                .onDisappear {
                    updateSetlist()
                }
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView(event: event)
        }
        .onAppear {
            checkNotificationStatus()
            eventSetlist = event.setlist
        }
    }
    
    // MARK: - Event Type Requirements
    
    // Проверка необходимости сетлиста для данного типа события
    func eventNeedsSetlist(_ type: String) -> Bool {
        return ["Concert", "Festival", "Rehearsal"].contains(type)
    }
    
    // Проверка необходимости информации о гостинице
    func eventNeedsHotel(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Photo Session", "Interview"].contains(type)
    }
    
    // Проверка необходимости информации о гонораре
    func eventNeedsFee(_ type: String) -> Bool {
        return ["Concert", "Festival", "Photo Session"].contains(type)
    }
    
    // Проверка необходимости информации о координаторе
    func eventNeedsCoordinator(_ type: String) -> Bool {
        return ["Concert", "Festival"].contains(type)
    }
    
    // Проверка необходимости информации об организаторе
    func eventNeedsOrganizer(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"].contains(type)
    }
    
    // MARK: - Actions
    
    // Обновление сетлиста события
    func updateSetlist() {
        let db = Firestore.firestore()
        db.collection("events").document(event.id).updateData([
            "setlist": eventSetlist
        ]) { error in
            if let error = error {
                print("❌ Ошибка при обновлении сетлиста: \(error.localizedDescription)")
            } else {
                print("✅ Сетлист события успешно обновлен")
            }
        }
    }
    
    // Проверка статуса уведомлений
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let hasNotification = requests.contains { $0.identifier.starts(with: "event-\(event.id)") }
                notificationsEnabled = hasNotification
            }
        }
    }
    
    // Звонок по номеру телефона
    private func callPhoneNumber(_ phoneNumber: String) {
        let formattedPhone = phoneNumber.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(formattedPhone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Отправка email
    private func sendEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Поделиться событием
    private func shareEvent() {
        // Создаем текст для шаринга
        let shareText = """
        Event: \(event.title)
        Type: \(event.type)
        Date: \(event.date.formatted(date: .long, time: .shortened))
        Location: \(event.location)
        """
        
        // Создаем ссылку или любой другой контент для шаринга
        let items: [Any] = [shareText]
        
        // Показываем стандартный UI для шаринга
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Находим rootViewController для представления UI шаринга
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    // Удаление события
    func deleteEvent() {
        // Создаем алерт для подтверждения
        let alert = UIAlertController(
            title: "Delete Event?",
            message: "This action cannot be undone",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            // Удаляем событие из Firebase
            Firestore.firestore().collection("events").document(event.id).delete { error in
                if error == nil {
                    // Удаляем связанные уведомления
                    NotificationService.shared.cancelEventNotifications(for: event.id)
                    
                    // Закрываем окно с деталями события
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("❌ Delete failed: \(error!.localizedDescription)")
                }
            }
        })
        
        // Показываем алерт
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}
// Добавьте в конец файла
struct NotificationSettingsView: View {
    let event: Event
    @Environment(\.presentationMode) var presentationMode
    @State private var isNotificationsAuthorized = false
    @State private var selectedReminderTime: ReminderTime = .oneHour
    @State private var enableNotification = true
    
    private let notificationService = NotificationService.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder Settings")) {
                    Toggle("Enable Event Reminder", isOn: $enableNotification)
                        .disabled(!isNotificationsAuthorized)
                    
                    if enableNotification {
                        Picker("Remind Me", selection: $selectedReminderTime) {
                            ForEach(ReminderTime.allCases) { time in
                                Text(time.rawValue).tag(time)
                            }
                        }
                        .disabled(!isNotificationsAuthorized)
                    }
                }
                
                if !isNotificationsAuthorized {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notifications Disabled")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("Please enable notifications in system settings to receive event reminders.")
                                .font(.caption)
                            
                            Button("Open Settings") {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section {
                    Button(action: saveSettings) {
                        Text("Save Settings")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                            .padding()
                            .background(isNotificationsAuthorized ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!isNotificationsAuthorized)
                }
            }
            .navigationTitle("Event Reminder")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Проверяем разрешение на уведомления
                notificationService.checkAuthorizationStatus { authorized in
                    isNotificationsAuthorized = authorized
                }
                
                // Проверяем, есть ли уже уведомление для этого события
                checkExistingNotification()
            }
        }
    }
    
    // Проверка существующего уведомления
    private func checkExistingNotification() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let matchingRequests = requests.filter { $0.identifier.starts(with: "event-\(event.id)") }
            
            if let existingRequest = matchingRequests.first {
                let identifier = existingRequest.identifier
                if let reminderType = identifier.components(separatedBy: "-").last,
                   let reminderTime = ReminderTime.allCases.first(where: { $0.rawValue == reminderType }) {
                    DispatchQueue.main.async {
                        selectedReminderTime = reminderTime
                        enableNotification = true
                    }
                }
            }
        }
    }
    
    // Сохранение настроек уведомлений
    private func saveSettings() {
        if enableNotification {
            notificationService.scheduleEventNotification(for: event, reminderTime: selectedReminderTime)
        } else {
            notificationService.cancelEventNotifications(for: event.id)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}
