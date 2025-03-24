import SwiftUI
import FirebaseFirestore
import FSCalendar

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var events: [Event] = []
    @State private var showingAddEventView = false

    var body: some View {
        NavigationView {
            VStack {
                // Calendar
                CalendarWrapper(selectedDate: $selectedDate, events: events)
                    .padding(.horizontal)
                    .frame(height: 300)

                // List of events for selected date
                if filteredEventsForSelectedDate.isEmpty {
                    VStack {
                        Spacer()
                        Text("No events for selected date")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredEventsForSelectedDate) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                HStack {
                                    Circle()
                                        .fill(colorForEventType(event.type))
                                        .frame(width: 12, height: 12)
                                    Text(event.icon)
                                        .font(.headline)
                                    VStack(alignment: .leading) {
                                        Text(event.title)
                                            .font(.headline)
                                        Text(event.location)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(formatTime(event.date))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Concert Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEventView = true }) {
                        Image(systemName: "plus")
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
    }

    // Filtered events for selected date
    var filteredEventsForSelectedDate: [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
        .sorted { $0.date < $1.date }
    }

    func fetchEvents() {
        let db = Firestore.firestore()
        db.collection("events").getDocuments { snapshot, error in
            if let snapshot = snapshot {
                self.events = snapshot.documents.compactMap { doc in
                    Event(from: doc.data(), id: doc.documentID)
                }
            }
        }
    }

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

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
