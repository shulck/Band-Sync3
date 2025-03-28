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
    @State private var setlistName: String? = nil
    @State private var isLoadingSetlist = false
    @State private var selectedSetlistId: String? = nil
    
    private let notificationService = NotificationService.shared
    
    var body: some View {
        ScrollView {
            // Верхний блок с заголовком и типом события
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Цветной фон в зависимости от типа события
                    Rectangle()
                        .fill(colorForEventType(event.type).opacity(0.15))
                        .frame(height: 150)
                    
                    // Информация о событии
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.type)
                                .font(.subheadline)
                                .foregroundColor(colorForEventType(event.type))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(colorForEventType(event.type).opacity(0.1))
                                .cornerRadius(8)
                            
                            Text(event.status)
                                .font(.subheadline)
                                .foregroundColor(event.status == "Confirmed" ? .green : .orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((event.status == "Confirmed" ? Color.green : Color.orange).opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(event.date.formatted(date: .long, time: .shortened))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemBackground).opacity(0.8))
                }
                
                // Блок местоположения
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                        
                        Text("Местоположение")
                            .font(.headline)
                    }
                    
                    Text(event.location)
                        .foregroundColor(.secondary)
                        .padding(.leading, 30)
                    
                    Button(action: {
                        showingMap.toggle()
                    }) {
                        Label(
                            showingMap ? "Скрыть карту" : "Показать на карте",
                            systemImage: showingMap ? "map.fill" : "map"
                        )
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.leading, 30)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 15)
                
                // Отображение карты
                if showingMap {
                    EventMapView(address: event.location)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                }
                
                // Информация об организаторе
                if eventNeedsOrganizer(event.type) || !event.organizer.name.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                            
                            Text("Организатор")
                                .font(.headline)
                        }
                        
                        if !event.organizer.name.isEmpty {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                
                                Text(event.organizer.name)
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 30)
                        }
                        
                        if !event.organizer.phone.isEmpty {
                            Button(action: {
                                callPhoneNumber(event.organizer.phone)
                            }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(event.organizer.phone)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                        }
                        
                        if !event.organizer.email.isEmpty {
                            Button(action: {
                                sendEmail(event.organizer.email)
                            }) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(event.organizer.email)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Информация о координаторе
                if eventNeedsCoordinator(event.type) || !event.coordinator.name.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.headline)
                                .foregroundColor(.purple)
                                .frame(width: 24, height: 24)
                            
                            Text("Координатор")
                                .font(.headline)
                        }
                        
                        if !event.coordinator.name.isEmpty {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                
                                Text(event.coordinator.name)
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 30)
                        }
                        
                        if !event.coordinator.phone.isEmpty {
                            Button(action: {
                                callPhoneNumber(event.coordinator.phone)
                            }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(event.coordinator.phone)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                        }
                        
                        if !event.coordinator.email.isEmpty {
                            Button(action: {
                                sendEmail(event.coordinator.email)
                            }) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(event.coordinator.email)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Информация о гостинице
                if eventNeedsHotel(event.type) && (!event.hotel.address.isEmpty || !event.hotel.checkIn.isEmpty) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bed.double.fill")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .frame(width: 24, height: 24)
                            
                            Text("Отель")
                                .font(.headline)
                        }
                        
                        if !event.hotel.address.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                
                                Text("Адрес: \(event.hotel.address)")
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 30)
                        }
                        
                        if !event.hotel.checkIn.isEmpty {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                
                                Text("Заезд: \(event.hotel.checkIn)")
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 30)
                        }
                        
                        if !event.hotel.checkOut.isEmpty {
                            HStack {
                                Image(systemName: "calendar.badge.minus")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                
                                Text("Выезд: \(event.hotel.checkOut)")
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 30)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Информация о гонораре
                if eventNeedsFee(event.type) && !event.fee.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                                .frame(width: 24, height: 24)
                            
                            Text("Гонорар")
                                .font(.headline)
                        }
                        
                        Text(event.fee)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.leading, 30)
                        
                        // Кнопка для перехода к финансам
                        NavigationLink(destination: EventFinancesView(event: event)) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                
                                Text("Просмотр финансов")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.leading, 30)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Сетлист
                if eventNeedsSetlist(event.type) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "music.note.list")
                                .font(.headline)
                                .foregroundColor(.indigo)
                                .frame(width: 24, height: 24)
                            
                            Text("Сетлист")
                                .font(.headline)
                        }
                        
                        if isLoadingSetlist {
                            ProgressView()
                                .padding(.leading, 30)
                        } else if let name = setlistName {
                            HStack {
                                Image(systemName: "music.quarternote.3")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                
                                Text(name)
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 30)
                            
                            Button(action: {
                                showingSetlistPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    
                                    Text("Изменить сетлист")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                        } else if let setlistId = event.setlistId {
                            Text("Загрузка сетлиста...")
                                .foregroundColor(.gray)
                                .padding(.leading, 30)
                        } else if !eventSetlist.isEmpty {
                            // Отображение песен
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Сетлист: \(eventSetlist.count) песен")
                                    .foregroundColor(.primary)
                                    .padding(.leading, 30)
                                
                                // Показываем только первые 3 песни, если их много
                                let displaySongs = eventSetlist.count > 3 ?
                                Array(eventSetlist.prefix(3)) + ["...и еще \(eventSetlist.count - 3)"] :
                                eventSetlist
                                
                                ForEach(displaySongs, id: \.self) { song in
                                    HStack {
                                        Image(systemName: "music.note")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(song)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 30)
                                }
                            }
                            
                            Button(action: {
                                showingSetlistPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    
                                    Text("Изменить сетлист")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                        } else {
                            Button(action: {
                                showingSetlistPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    
                                    Text("Добавить сетлист")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 30)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Расписание дня
                if !event.schedule.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundColor(.teal)
                                .frame(width: 24, height: 24)
                            
                            Text("Расписание дня")
                                .font(.headline)
                        }
                        
                        ForEach(event.schedule) { item in
                            HStack(alignment: .top) {
                                Text(item.time)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .frame(width: 50, alignment: .leading)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.teal.opacity(0.1))
                                    .cornerRadius(6)
                                
                                Text(item.activity)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 4)
                            }
                            .padding(.leading, 30)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Заметки
                if !event.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 24)
                            
                            Text("Заметки")
                                .font(.headline)
                        }
                        
                        Text(event.notes)
                            .foregroundColor(.primary)
                            .padding(.leading, 30)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                }
                
                // Уведомления
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .frame(width: 24, height: 24)
                        
                        Text("Уведомления")
                            .font(.headline)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if notificationsEnabled {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    
                                    Text("Напоминание установлено")
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.secondary)
                                    
                                    Text("Нет напоминаний")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingNotificationSettings = true
                        }) {
                            Text("Настроить")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.leading, 30)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 15)
                
                // Кнопки действий
                VStack(spacing: 12) {
                    Button(action: {
                        showingEdit = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Редактировать событие")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            shareEvent()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Поделиться")
                            }
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        Button(action: deleteEvent) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Удалить")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Детали события")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingSetlistPicker) {
            SetlistPickerView(selectedSetlist: $eventSetlist, selectedSetlistId: $selectedSetlistId)
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
            selectedSetlistId = event.setlistId
            
            // Загружаем название сетлиста, если есть setlistId
            if let setlistId = event.setlistId {
                isLoadingSetlist = true
                fetchSetlistName(setlistId: setlistId) { name in
                    DispatchQueue.main.async {
                        self.setlistName = name
                        self.isLoadingSetlist = false
                    }
                }
            } else {
                // Используем кэшированное название, если есть
                setlistName = event.setlistName
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Получение цвета для типа события
    func colorForEventType(_ type: String) -> Color {
        switch type {
        case "Concert": return .red
        case "Festival": return .orange
        case "Meeting": return .yellow
        case "Rehearsal": return .green
        case "Photo Session": return .blue
        case "Interview": return .purple
        default: return .gray
        }
    }
    
    // Загрузка имени сетлиста
    func fetchSetlistName(setlistId: String, completion: @escaping (String?) -> Void) {
        guard !setlistId.isEmpty else {
            completion(nil)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("setlists").document(setlistId).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                let setlistName = data["name"] as? String
                completion(setlistName)
            } else {
                completion(nil)
            }
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
        
        if let selectedId = selectedSetlistId {
            // Обновляем документ события с ID сетлиста и (опционально) списком песен
            db.collection("events").document(event.id).updateData([
                "setlistId": selectedId,
                "setlist": eventSetlist // для обратной совместимости
            ]) { error in
                if let error = error {
                    print("❌ Ошибка при обновлении сетлиста: \(error.localizedDescription)")
                } else {
                    print("✅ Сетлист события успешно обновлен")
                    
                    // После сохранения ID сетлиста, загружаем его название
                    fetchSetlistName(setlistId: selectedId) { name in
                        if let name = name {
                            DispatchQueue.main.async {
                                self.setlistName = name
                                
                                // Также сохраняем название сетлиста в документе события для кэширования
                                db.collection("events").document(event.id).updateData([
                                    "setlistName": name
                                ])
                            }
                        }
                    }
                }
            }
        } else {
            // Если нет выбранного ID сетлиста, но есть песни (старый вариант)
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
    }
    
    // Проверка статуса уведомлений
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let hasNotification = requests.contains { $0.identifier.starts(with: "event-\(event.id)") }
                notificationsEnabled = hasNotification
            }
        }
    }
    
    // Звонок по номеру телефона
    func callPhoneNumber(_ phoneNumber: String) {
        let formattedPhone = phoneNumber.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(formattedPhone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Отправка email
    func sendEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Поделиться событием
    func shareEvent() {
        // Создаем текст для шаринга
        let shareText = """
        Событие: \(event.title)
        Тип: \(event.type)
        Дата: \(event.date.formatted(date: .long, time: .shortened))
        Место: \(event.location)
        """
        
        // Показываем стандартный UI для шаринга
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // Находим rootViewController для представления UI шаринга
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    // Удаление события
    func deleteEvent() {
        // Проверяем, является ли событие повторяющимся
        if event.isRecurring {
            // Создаем AlertController для выбора опции удаления
            let alert = UIAlertController(
                title: "Delete Recurring Event",
                message: "Would you like to delete just this occurrence or all occurrences of this event?",
                preferredStyle: .alert
            )
            
            // Кнопка для удаления только этого экземпляра
            alert.addAction(UIAlertAction(title: "This Occurrence Only", style: .default) { _ in
                // Удаляем только экземпляр, если это повторяющееся событие
                // Логика для создания исключения в повторении...
                self.deleteSingleOccurrence()
            })
            
            // Кнопка для удаления всех экземпляров
            alert.addAction(UIAlertAction(title: "All Occurrences", style: .destructive) { _ in
                // Удаляем все повторяющееся событие
                self.deleteAllOccurrences()
            })
            
            // Кнопка отмены
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // Показываем alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        } else {
            // Если событие не повторяется, просто подтверждаем удаление
            let alert = UIAlertController(
                title: "Delete Event?",
                message: "This action cannot be undone",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                self.deleteAllOccurrences()
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    // Удалить только один экземпляр повторяющегося события
    private func deleteSingleOccurrence() {
        // Здесь мы создаем исключение в повторяющемся событии
        // В настоящей реализации вам нужно сохранить дату как исключение
        
        let db = Firestore.firestore()
        
        // Проверяем, есть ли уже исключения
        db.collection("events").document(event.id).getDocument { (document, error) in
            if let document = document, let data = document.data() {
                var exceptions = data["exceptions"] as? [Timestamp] ?? []
                exceptions.append(Timestamp(date: event.date))
                
                // Обновляем документ с новым исключением
                db.collection("events").document(event.id).updateData([
                    "exceptions": exceptions
                ]) { error in
                    if error == nil {
                        // Успешно добавлено исключение
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // Удалить все повторяющиеся события
    private func deleteAllOccurrences() {
        let db = Firestore.firestore()
        db.collection("events").document(event.id).delete { error in
            if error == nil {
                // Удаляем связанные уведомления
                NotificationService.shared.cancelEventNotifications(for: event.id)
                
                // Закрываем окно с деталями события
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    // MARK: - Настройки уведомлений
    
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
                    Section(header: Text("Настройки напоминания")) {
                        Toggle("Включить напоминание о событии", isOn: $enableNotification)
                            .disabled(!isNotificationsAuthorized)
                        
                        if enableNotification {
                            Picker("Напомнить", selection: $selectedReminderTime) {
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
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Уведомления отключены")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Text("Пожалуйста, включите уведомления в настройках системы, чтобы получать напоминания о событиях.")
                                    .font(.callout)
                                
                                Button("Открыть настройки") {
                                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsURL)
                                    }
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    Section {
                        Button(action: saveSettings) {
                            Text("Сохранить настройки")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                                .padding()
                                .background(isNotificationsAuthorized ? Color.blue : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(!isNotificationsAuthorized)
                    }
                }
                .navigationTitle("Напоминание о событии")
                .navigationBarItems(trailing: Button("Отмена") {
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
    
    // MARK: - Supporting Components
    
    // Компонент секции формы
    struct FormSection<Content: View>: View {
        var title: String
        @ViewBuilder var content: Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                content
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
    
    // Переименовываем FormField, чтобы избежать конфликта имен, добавив префикс Detail
    struct DetailFormField<Content: View>: View {
        var title: String
        var systemImage: String
        @ViewBuilder var content: Content
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    content
                }
            }
        }
    }
}
