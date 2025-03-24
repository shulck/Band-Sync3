import SwiftUI
import FirebaseFirestore

struct EditEventView: View {
    @Environment(\.presentationMode) var presentationMode
    var event: Event

    @State private var updatedEvent: Event
    @State private var showingLocationSearch = false
    @State private var showingSetlistPicker = false

    init(event: Event) {
        self.event = event
        _updatedEvent = State(initialValue: event)
    }

    // MARK: - Event Type Requirements

    // Проверяем, нужен ли сетлист для данного типа события
    private func eventNeedsSetlist(_ type: String) -> Bool {
        return ["Concert", "Festival", "Rehearsal"].contains(type)
    }

    // Проверяем, нужна ли информация об отеле
    private func eventNeedsHotel(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Photo Session", "Interview"].contains(type)
    }

    // Проверяем, нужен ли гонорар
    private func eventNeedsFee(_ type: String) -> Bool {
        return ["Concert", "Festival", "Photo Session"].contains(type)
    }

    // Проверяем, нужен ли координатор
    private func eventNeedsCoordinator(_ type: String) -> Bool {
        return ["Concert", "Festival"].contains(type)
    }

    // Проверяем, нужен ли организатор
    private func eventNeedsOrganizer(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"].contains(type)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Main Information")) {
                    TextField("Name", text: $updatedEvent.title)
                    DatePicker("Date", selection: $updatedEvent.date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Type", selection: $updatedEvent.type) {
                        ForEach(["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"], id: \.self) {
                            Text($0)
                        }
                    }
                    Picker("Status", selection: $updatedEvent.status) {
                        ForEach(["Reserved", "Confirmed"], id: \.self) {
                            Text($0)
                        }
                    }
                }

                Section(header: Text("Location")) {
                    HStack {
                        TextField("Location", text: $updatedEvent.location)
                        Button(action: {
                            showingLocationSearch = true
                        }) {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Секция организатора показывается для всех типов событий
                if eventNeedsOrganizer(updatedEvent.type) {
                    Section(header: Text("Organizer")) {
                        TextField("Name", text: $updatedEvent.organizer.name)
                        TextField("Phone", text: $updatedEvent.organizer.phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $updatedEvent.organizer.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }

                // Секция координатора показывается только для концертов и фестивалей
                if eventNeedsCoordinator(updatedEvent.type) {
                    Section(header: Text("Coordinator")) {
                        TextField("Name", text: $updatedEvent.coordinator.name)
                        TextField("Phone", text: $updatedEvent.coordinator.phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $updatedEvent.coordinator.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }

                // Секция отеля показывается для определенных типов событий
                if eventNeedsHotel(updatedEvent.type) {
                    Section(header: Text("Hotel")) {
                        TextField("Address", text: $updatedEvent.hotel.address)
                        TextField("Check-in", text: $updatedEvent.hotel.checkIn)
                        TextField("Check-out", text: $updatedEvent.hotel.checkOut)
                    }
                }

                // Секция гонорара показывается только для концертов, фестивалей и фотосессий
                if eventNeedsFee(updatedEvent.type) {
                    Section(header: Text("Fee")) {
                        TextField("Amount", text: $updatedEvent.fee)
                            .keyboardType(.decimalPad)
                    }
                }

                // Секция сетлиста показывается только для концертов, фестивалей и репетиций
                if eventNeedsSetlist(updatedEvent.type) {
                    Section(header: Text("Setlist")) {
                        if updatedEvent.setlist.isEmpty {
                            Text("No setlist selected")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(updatedEvent.setlist, id: \.self) { song in
                                Text(song)
                            }
                            .onDelete { indices in
                                var newSetlist = updatedEvent.setlist
                                newSetlist.remove(atOffsets: indices)
                                updatedEvent.setlist = newSetlist
                            }
                        }

                        Button("Change setlist") {
                            showingSetlistPicker = true
                        }
                    }
                }

                // Секция расписания показывается для всех типов событий
                Section(header: Text("Daily Schedule")) {
                    ForEach(0..<updatedEvent.schedule.count, id: \.self) { index in
                        HStack {
                            TextField("Time", text: Binding(
                                get: { updatedEvent.schedule[index].time },
                                set: { updatedEvent.schedule[index].time = $0 }
                            ))
                            .frame(width: 80)
                            .keyboardType(.numbersAndPunctuation)

                            TextField("Event", text: Binding(
                                get: { updatedEvent.schedule[index].activity },
                                set: { updatedEvent.schedule[index].activity = $0 }
                            ))
                        }
                    }
                    .onDelete(perform: deleteScheduleItem)

                    Button(action: addScheduleItem) {
                        Label("Add schedule item", systemImage: "plus")
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $updatedEvent.notes)
                        .frame(height: 100)
                }

                Button("Save changes", action: saveChanges)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .navigationTitle("Edit Event")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchView(selectedLocation: $updatedEvent.location)
            }
            .sheet(isPresented: $showingSetlistPicker) {
                SetlistPickerView(selectedSetlist: $updatedEvent.setlist)
                    .onDisappear {
                        // Можно добавить для отладки
                        print("📝 Setlist picker закрыт, выбран сетлист: \(updatedEvent.setlist)")
                    }
            }
        }
    }

    func addScheduleItem() {
        var updatedSchedule = updatedEvent.schedule
        updatedSchedule.append(DailyScheduleItem(time: "12:00", activity: ""))
        updatedEvent.schedule = updatedSchedule
    }

    func deleteScheduleItem(at offsets: IndexSet) {
        var updatedSchedule = updatedEvent.schedule
        updatedSchedule.remove(atOffsets: offsets)
        updatedEvent.schedule = updatedSchedule
    }

    func saveChanges() {
        Firestore.firestore()
            .collection("events")
            .document(event.id)
            .setData(updatedEvent.asDictionary) { error in
                if error == nil {
                    // Сохраняем или обновляем контакты
                    saveContact(updatedEvent.organizer, role: "Organizer")
                    saveContact(updatedEvent.coordinator, role: "Coordinator")

                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("❌ Edit error: \(error!.localizedDescription)")
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
            "venue": updatedEvent.location,
            "rating": 0,
            "notes": "",
            "createdAt": FieldValue.serverTimestamp()
        ]

        // Проверяем наличие контакта по имени (вместо телефона, который может быть пустым)
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
