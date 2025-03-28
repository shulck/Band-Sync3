import SwiftUI
import FirebaseFirestore
import FSCalendar
import FirebaseAuth

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var events: [Event] = []
    @State private var showingAddEventView = false

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя карточка с календарем
            VStack(spacing: 0) {
                // Calendar
                CalendarWrapper(selectedDate: $selectedDate, events: events)
                    .padding(.horizontal)
                    .frame(height: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    .padding(.top)
                
                // Убрали индикатор типов событий для более чистого интерфейса
                Spacer()
                    .frame(height: 10)
            }
            .background(Color(UIColor.systemBackground))
            
            // Заголовок списка событий для выбранной даты
            HStack {
                VStack(alignment: .leading) {
                    Text(formattedSelectedDate)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(getEventCountText(count: filteredEventsForSelectedDate.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                Spacer()
            }

            // Список событий для выбранной даты
            if filteredEventsForSelectedDate.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(Color.gray.opacity(0.5))
                        
                        Text("Нет событий на выбранную дату")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: { showingAddEventView = true }) {
                            Label("Добавить событие", systemImage: "plus.circle.fill")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEventsForSelectedDate) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                EnhancedEventRow(event: event)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationTitle("Календарь событий")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEventView = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddEventView) {
            AddEventView(onSave: { newEvent in
                events.append(newEvent)
            })
        }
        .onAppear {
            fetchEvents()
        }
    }

    // Вычисляемое свойство для форматированной выбранной даты
    var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    // Вспомогательный метод для получения текста с количеством событий
    func getEventCountText(count: Int) -> String {
        switch count {
        case 0:
            return "Нет событий"
        case 1:
            return "1 событие"
        case 2, 3, 4:
            return "\(count) события"
        default:
            return "\(count) событий"
        }
    }

    // Отфильтрованные события для выбранной даты
    var filteredEventsForSelectedDate: [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
        .sorted { $0.date < $1.date }
    }

    // Получение данных о событиях из Firebase
    func fetchEvents() {
        // Сначала получаем ID группы текущего пользователя
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Пользователь не авторизован")
            return
        }
        
        let db = Firestore.firestore()
        
        // Получаем groupId текущего пользователя
        db.collection("users").document(currentUserId).getDocument { userDoc, userError in
            if let userError = userError {
                print("Ошибка при получении данных пользователя: \(userError.localizedDescription)")
                return
            }
            
            guard let userData = userDoc?.data(),
                  let groupId = userData["groupId"] as? String else {
                print("Не удалось получить ID группы пользователя")
                return
            }
            
            // Теперь получаем только события для этой группы
            db.collection("events")
              .whereField("groupId", isEqualTo: groupId)
              .getDocuments { snapshot, error in
                if let error = error {
                    print("Ошибка при получении событий: \(error.localizedDescription)")
                    return
                }
                
                if let snapshot = snapshot {
                    self.events = snapshot.documents.compactMap { doc in
                        Event(from: doc.data(), id: doc.documentID)
                    }
                }
            }
        }
    }

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

    // Форматирование времени
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Улучшенная карточка события
struct EnhancedEventRow: View {
    var event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Цветовой индикатор и иконка типа события
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForEventType(event.type).opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Text(event.icon)
                        .font(.title2)
                }
                
                // Время события
                Text(formatTime(event.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 48)
            
            // Информация о событии
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(event.type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(colorForEventType(event.type).opacity(0.1))
                        .cornerRadius(4)
                        .foregroundColor(colorForEventType(event.type))
                    
                    Text(event.status)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(event.status == "Confirmed" ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(4)
                        .foregroundColor(event.status == "Confirmed" ? .green : .orange)
                }
                
                // Локация
                if !event.location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(event.location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // Определение цвета для типа события
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
    
    // Форматирование времени
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Предпросмотр
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CalendarView()
        }
    }

    }
