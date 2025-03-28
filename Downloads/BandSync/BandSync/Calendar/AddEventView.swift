import SwiftUI
import FirebaseFirestore
import MapKit

struct AddEventView: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (Event) -> Void

    @State private var title = ""
    @State private var date = Date()
    @State private var type = "Concert"
    @State private var status = "Reserved"
    @State private var location = ""
    @State private var fee = ""
    @State private var notes = ""
    @State private var searchLocation = ""
    @State private var showingLocationSearch = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var organizer = EventContact(name: "", phone: "", email: "")
    @State private var coordinator = EventContact(name: "", phone: "", email: "")
    @State private var hotel = Hotel(address: "", checkIn: "", checkOut: "")

    @State private var setlist: [String] = []
    @State private var schedule: [DailyScheduleItem] = []
    @State private var showingSetlistPicker = false
    @State private var isPersonalEvent = false
    @State private var currentSection = 0 // 0 - основная информация, 1 - детали, 2 - расписание

    // Шаблоны для автоматического заполнения
    let eventTemplates: [String: [String: Any]] = [
        "Concert": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "16:00", activity: "Arrival & Setup"),
                DailyScheduleItem(time: "17:30", activity: "Soundcheck"),
                DailyScheduleItem(time: "19:00", activity: "Doors Open"),
                DailyScheduleItem(time: "20:00", activity: "Show Start"),
                DailyScheduleItem(time: "22:00", activity: "Show End & Merch")
            ]
        ],
        "Festival": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "12:00", activity: "Arrival & Check-in"),
                DailyScheduleItem(time: "14:30", activity: "Stage Setup"),
                DailyScheduleItem(time: "15:30", activity: "Soundcheck"),
                DailyScheduleItem(time: "17:00", activity: "Performance"),
                DailyScheduleItem(time: "18:00", activity: "Meet & Greet")
            ]
        ],
        "Rehearsal": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "10:00", activity: "Setup Equipment"),
                DailyScheduleItem(time: "10:30", activity: "Warm-up"),
                DailyScheduleItem(time: "11:00", activity: "Full Rehearsal"),
                DailyScheduleItem(time: "13:00", activity: "Break"),
                DailyScheduleItem(time: "14:00", activity: "Specific Songs Practice")
            ]
        ],
        "Photo Session": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "09:00", activity: "Makeup & Styling"),
                DailyScheduleItem(time: "10:30", activity: "Individual Shots"),
                DailyScheduleItem(time: "12:00", activity: "Group Shots"),
                DailyScheduleItem(time: "13:30", activity: "Break"),
                DailyScheduleItem(time: "14:30", activity: "Outdoor/Special Location Shots")
            ]
        ],
        "Interview": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "13:00", activity: "Arrival & Briefing"),
                DailyScheduleItem(time: "13:30", activity: "Sound & Light Check"),
                DailyScheduleItem(time: "14:00", activity: "Interview Start"),
                DailyScheduleItem(time: "15:00", activity: "B-roll Shooting"),
                DailyScheduleItem(time: "15:30", activity: "Wrap-up")
            ]
        ],
        "Meeting": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "10:00", activity: "Meeting Start"),
                DailyScheduleItem(time: "11:30", activity: "Discussion"),
                DailyScheduleItem(time: "12:30", activity: "Lunch"),
                DailyScheduleItem(time: "13:30", activity: "Follow-up Planning"),
                DailyScheduleItem(time: "15:00", activity: "Meeting End")
            ]
        ]
    ]

    let eventTypes = ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"]
    let statusOptions = ["Reserved", "Confirmed"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Переключатель секций
                    SegmentedPicker(
                        options: ["Основное", "Детали", "Расписание"],
                        selectedIndex: $currentSection
                    )
                    .padding(.horizontal)
                    .padding(.top)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if currentSection == 0 {
                                // СЕКЦИЯ 1: ОСНОВНАЯ ИНФОРМАЦИЯ
                                FormCard {
                                    // Название события
                                    FormField(title: "Название события", systemImage: "square.text.square") {
                                        TextField("Введите название", text: $title)
                                            .font(.headline)
                                    }
                                    
                                    Divider()
                                    
                                    // Дата события
                                    FormField(title: "Дата и время", systemImage: "calendar") {
                                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                            .labelsHidden()
                                    }
                                    
                                    Divider()
                                    
                                    // Тип события
                                    FormField(title: "Тип события", systemImage: "music.note.list") {
                                        Menu {
                                            ForEach(eventTypes, id: \.self) { eventType in
                                                Button(action: {
                                                    type = eventType
                                                    
                                                    // Заполнение шаблона расписания при изменении типа
                                                    if let template = eventTemplates[eventType],
                                                       let scheduleTemplate = template["scheduleTemplate"] as? [DailyScheduleItem] {
                                                        schedule = scheduleTemplate
                                                    }
                                                }) {
                                                    HStack {
                                                        Text(eventType)
                                                        if type == eventType {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(type)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Статус
                                    FormField(title: "Статус", systemImage: "star") {
                                        Menu {
                                            ForEach(statusOptions, id: \.self) { option in
                                                Button(action: { status = option }) {
                                                    HStack {
                                                        Text(option)
                                                        if status == option {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(status)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Местоположение
                                    FormField(title: "Местоположение", systemImage: "mappin.and.ellipse") {
                                        HStack {
                                            TextField("Введите адрес", text: $location)
                                            
                                            Button(action: {
                                                showingLocationSearch = true
                                            }) {
                                                Image(systemName: "magnifyingglass")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Личное событие
                                    FormField(title: "Личное событие", systemImage: "person.crop.circle") {
                                        Toggle("", isOn: $isPersonalEvent)
                                            .tint(.blue)
                                    }
                                }
                                
                                // Примечания
                                FormCard {
                                    FormField(title: "Примечания", systemImage: "note.text") {
                                        ZStack(alignment: .leading) {
                                            if notes.isEmpty {
                                                Text("Добавьте примечания к событию")
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 8)
                                            }
                                            
                                            TextEditor(text: $notes)
                                                .frame(height: 100)
                                                .opacity(notes.isEmpty ? 0.25 : 1)
                                        }
                                    }
                                }
                                
                                // Кнопка перехода к следующей секции
                                Button(action: { currentSection = 1 }) {
                                    HStack {
                                        Text("Далее: Детали")
                                        Image(systemName: "arrow.right")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue)
                                    )
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                }
                            }
                            else if currentSection == 1 {
                                // СЕКЦИЯ 2: ДЕТАЛИ
                                
                                // Организатор
                                if eventNeedsOrganizer(type) {
                                    FormCard {
                                        Text("Организатор")
                                            .font(.headline)
                                            .padding(.bottom, 8)
                                        
                                        FormField(title: "Имя", systemImage: "person") {
                                            TextField("Имя организатора", text: $organizer.name)
                                        }
                                        
                                        Divider()
                                        
                                        FormField(title: "Телефон", systemImage: "phone") {
                                            TextField("Телефон организатора", text: $organizer.phone)
                                                .keyboardType(.phonePad)
                                        }
                                        
                                        Divider()
                                        
                                        FormField(title: "Email", systemImage: "envelope") {
                                            TextField("Email организатора", text: $organizer.email)
                                                .keyboardType(.emailAddress)
                                                .autocapitalization(.none)
                                        }
                                    }
                                }
                                
                                // Координатор
                                if eventNeedsCoordinator(type) {
                                    FormCard {
                                        Text("Координатор")
                                            .font(.headline)
                                            .padding(.bottom, 8)
                                        
                                        FormField(title: "Имя", systemImage: "person") {
                                            TextField("Имя координатора", text: $coordinator.name)
                                        }
                                        
                                        Divider()
                                        
                                        FormField(title: "Телефон", systemImage: "phone") {
                                            TextField("Телефон координатора", text: $coordinator.phone)
                                                .keyboardType(.phonePad)
                                        }
                                        
                                        Divider()
                                        
                                        FormField(title: "Email", systemImage: "envelope") {
                                            TextField("Email координатора", text: $coordinator.email)
                                                .keyboardType(.emailAddress)
                                                .autocapitalization(.none)
                                        }
                                    }
                                }
                                
                                // Отель
                                if eventNeedsHotel(type) {
                                    FormCard {
                                        Text("Отель")
                                            .font(.headline)
                                            .padding(.bottom, 8)
                                        
                                        FormField(title: "Адрес", systemImage: "mappin") {
                                            TextField("Адрес отеля", text: $hotel.address)
                                        }
                                        
                                        Divider()
                                        
                                        FormField(title: "Заезд", systemImage: "calendar.badge.plus") {
                                            TextField("Время заезда", text: $hotel.checkIn)
                                        }
                                        
                                        Divider()
                                        
                                        FormField(title: "Выезд", systemImage: "calendar.badge.minus") {
                                            TextField("Время выезда", text: $hotel.checkOut)
                                        }
                                    }
                                }
                                
                                // Гонорар
                                if eventNeedsFee(type) {
                                    FormCard {
                                        FormField(title: "Гонорар", systemImage: "dollarsign.circle") {
                                            TextField("Сумма гонорара", text: $fee)
                                                .keyboardType(.decimalPad)
                                        }
                                    }
                                }
                                
                                // Сетлист
                                if eventNeedsSetlist(type) {
                                    FormCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Сетлист")
                                                .font(.headline)
                                            
                                            if setlist.isEmpty {
                                                Text("Сетлист не выбран")
                                                    .foregroundColor(.secondary)
                                            } else {
                                                ForEach(setlist, id: \.self) { song in
                                                    HStack {
                                                        Image(systemName: "music.note")
                                                            .foregroundColor(.secondary)
                                                        
                                                        Text(song)
                                                    }
                                                }
                                            }
                                            
                                            Button(action: {
                                                showingSetlistPicker = true
                                            }) {
                                                Label(
                                                    setlist.isEmpty ? "Выбрать сетлист" : "Изменить сетлист",
                                                    systemImage: setlist.isEmpty ? "plus.circle" : "pencil"
                                                )
                                                .foregroundColor(.blue)
                                                .padding(.top, 4)
                                            }
                                        }
                                        .padding()
                                    }
                                }
                                
                                // Кнопки навигации
                                HStack(spacing: 12) {
                                    Button(action: { currentSection = 0 }) {
                                        HStack {
                                            Image(systemName: "arrow.left")
                                            Text("Назад")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                        .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: { currentSection = 2 }) {
                                        HStack {
                                            Text("Далее")
                                            Image(systemName: "arrow.right")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.blue)
                                        )
                                        .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom)
                            }
                            else if currentSection == 2 {
                                // СЕКЦИЯ 3: РАСПИСАНИЕ
                                FormCard {
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Text("Расписание дня")
                                                .font(.headline)
                                            
                                            Spacer()
                                            
                                            Button(action: addScheduleItem) {
                                                Label("Добавить", systemImage: "plus.circle")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        if schedule.isEmpty {
                                            HStack {
                                                Spacer()
                                                
                                                VStack(spacing: 8) {
                                                    Image(systemName: "calendar.badge.clock")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.secondary)
                                                    
                                                    Text("Нет пунктов расписания")
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 20)
                                        } else {
                                            ForEach(0..<schedule.count, id: \.self) { index in
                                                HStack(alignment: .center, spacing: 12) {
                                                    // Время
                                                    TextField("00:00", text: Binding(
                                                        get: { schedule[index].time },
                                                        set: { schedule[index].time = $0 }
                                                    ))
                                                    .frame(width: 80)
                                                    .padding(8)
                                                    .background(Color(UIColor.systemBackground))
                                                    .cornerRadius(8)
                                                    .keyboardType(.numberPad)
                                                    
                                                    // Событие
                                                    TextField("Описание", text: Binding(
                                                        get: { schedule[index].activity },
                                                        set: { schedule[index].activity = $0 }
                                                    ))
                                                    .padding(8)
                                                    .background(Color(UIColor.systemBackground))
                                                    .cornerRadius(8)
                                                    
                                                    // Кнопка удаления
                                                    Button(action: {
                                                        deleteScheduleItem(at: IndexSet(integer: index))
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                }
                                
                                // Кнопки навигации
                                HStack(spacing: 12) {
                                    Button(action: { currentSection = 1 }) {
                                        HStack {
                                            Image(systemName: "arrow.left")
                                            Text("Назад")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                        .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: saveEvent) {
                                        HStack {
                                            Image(systemName: "checkmark")
                                            Text("Сохранить")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(title.isEmpty ? Color.gray : Color.blue)
                                        )
                                        .foregroundColor(.white)
                                    }
                                    .disabled(title.isEmpty)
                                }
                                .padding(.horizontal)
                                .padding(.bottom)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Новое событие")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Отмена") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchView(selectedLocation: $location)
            }
            .sheet(isPresented: $showingSetlistPicker) {
                SetlistPickerView(selectedSetlist: $setlist)
            }
        }
    }

    // Проверка необходимости сетлиста для данного типа события
    private func eventNeedsSetlist(_ type: String) -> Bool {
        return ["Concert", "Festival", "Rehearsal"].contains(type)
    }

    // Проверка необходимости информации об отеле
    private func eventNeedsHotel(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Photo Session", "Interview"].contains(type)
    }

    // Проверка необходимости информации о гонораре
    private func eventNeedsFee(_ type: String) -> Bool {
        return ["Concert", "Festival", "Photo Session"].contains(type)
    }

    // Проверка необходимости информации о координаторе
    private func eventNeedsCoordinator(_ type: String) -> Bool {
        return ["Concert", "Festival"].contains(type)
    }

    // Проверка необходимости информации об организаторе
    private func eventNeedsOrganizer(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"].contains(type)
    }

    func addScheduleItem() {
        let newItem = DailyScheduleItem(time: "12:00", activity: "")
        schedule.append(newItem)
    }

    func deleteScheduleItem(at offsets: IndexSet) {
        schedule.remove(atOffsets: offsets)
    }

    func saveEvent() {
        let db = Firestore.firestore()
        let event = Event(
            id: UUID().uuidString,
            title: title,
            date: date,
            type: type,
            status: status,
            location: location,
            organizer: organizer,
            coordinator: coordinator,
            hotel: hotel,
            fee: fee,
            setlist: setlist,
            notes: notes,
            isPersonal: isPersonalEvent,
            schedule: schedule
        )
        

        db.collection("events").document(event.id).setData([
            "id": event.id,
            "title": title,
            "date": Timestamp(date: date),
            "type": type,
            "status": status,
            "location": location,
            "fee": fee,
            "notes": notes,
            "setlist": setlist,
            "isPersonal": isPersonalEvent,
            "organizer": [
                "name": organizer.name,
                "phone": organizer.phone,
                "email": organizer.email
            ],
            "coordinator": [
                "name": coordinator.name,
                "phone": coordinator.phone,
                "email": coordinator.email
            ],
            "hotel": [
                "address": hotel.address,
                "checkIn": hotel.checkIn,
                "checkOut": hotel.checkOut
            ],
            "schedule": schedule.map { ["time": $0.time, "activity": $0.activity, "id": $0.id] }
        ]) { error in
            if let error = error {
                print("❌ Error saving event: \(error.localizedDescription)")
            } else {
                saveContact(organizer, role: "Organizer")
                saveContact(coordinator, role: "Coordinator")

                onSave(event)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // Функция для сохранения контактов в Firebase
    func saveContact(_ contact: EventContact, role: String) {
        // Проверяем, что хотя бы имя указано
        if contact.name.isEmpty {
            return // Пропускаем пустые контакты
        }

        let db = Firestore.firestore()
        let contactData: [String: Any] = [
            "name": contact.name,
            "phone": contact.phone,
            "email": contact.email,
            "role": role,
            "venue": location,
            "rating": 0,
            "notes": "",
            "createdAt": FieldValue.serverTimestamp()
        ]

        // Проверяем наличие контакта по имени
        db.collection("contacts")
            .whereField("name", isEqualTo: contact.name)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error checking contact: \(error.localizedDescription)")
                    return
                }

                if let snapshot = snapshot, snapshot.documents.isEmpty {
                    // Если контакт не существует, создаем новый с уникальным ID
                    db.collection("contacts").document().setData(contactData) { error in
                        if let error = error {
                            print("❌ Error saving contact: \(error.localizedDescription)")
                        } else {
                            print("✅ Contact saved successfully")
                        }
                    }
                } else {
                    // Если контакт существует, обновляем информацию
                    if let document = snapshot?.documents.first {
                        // Добавляем поле обновления
                        var updatedData = contactData
                        updatedData["updatedAt"] = FieldValue.serverTimestamp()

                        db.collection("contacts").document(document.documentID).updateData(updatedData) { error in
                            if let error = error {
                                print("❌ Error updating contact: \(error.localizedDescription)")
                            } else {
                                print("✅ Contact updated successfully")
                            }
                        }
                    }
                }
            }
    }
}

// MARK: - Вспомогательные компоненты

struct FormCard<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        content
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
            .padding(.horizontal)
    }
}

struct FormField<Content: View>: View {
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
        .padding(.vertical, 4)
    }
}

struct SegmentedPicker: View {
    var options: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedIndex = index
                    }
                }) {
                    Text(options[index])
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                }
                .background(selectedIndex == index ? Color.blue : Color.clear)
                .foregroundColor(selectedIndex == index ? .white : .primary)
            }
        }
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}
