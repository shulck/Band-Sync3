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
            // Top card with calendar
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

                // Removed event type indicators for a cleaner interface
                Spacer()
                    .frame(height: 10)
            }
            .background(Color(UIColor.systemBackground))

            // Header for the list of events for the selected date
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

            // List of events for the selected date
            if filteredEventsForSelectedDate.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(Color.gray.opacity(0.5))

                        Text("No events for the selected date")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Button(action: { showingAddEventView = true }) {
                            Label("Add event", systemImage: "plus.circle.fill")
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
        .navigationTitle("Calendar")
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

    // Computed property for formatted selected date
    var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    // Helper method for getting text with event count
    func getEventCountText(count: Int) -> String {
        switch count {
        case 0:
            return "No events"
        case 1:
            return "1 event"
        case 2, 3, 4:
            return "\(count) events"
        default:
            return "\(count) events"
        }
    }

    // Filtered events for the selected date
    var filteredEventsForSelectedDate: [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
        .sorted { $0.date < $1.date }
    }

    // Getting event data from Firebase
    func fetchEvents() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            guard let document = document, document.exists,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else { return }

            print("Loading events for group: \(groupId)")

            db.collection("events")
              .whereField("groupId", isEqualTo: groupId)
              .getDocuments { snapshot, error in
                if let snapshot = snapshot {
                    // Loading basic events
                    let baseEvents = snapshot.documents.compactMap { doc in
                        Event(from: doc.data(), id: doc.documentID)
                    }

                    // Processing recurring events
                    var allEvents = [Event]()
                    let calendar = Calendar.current
                    let startDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                    let endDate = calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()

                    for event in baseEvents {
                        if event.isRecurring, let recurrenceType = event.recurrenceType {
                            // Get all dates for recurring events
                            let dates = RecurrenceHelper.getRecurringEventDates(
                                event: event,
                                startDate: startDate,
                                endDate: endDate
                            )

                            // Create virtual instances for each date
                            for date in dates {
                                var recEvent = event
                                recEvent.date = date
                                allEvents.append(recEvent)
                            }
                        } else {
                            allEvents.append(event)
                        }
                    }

                    self.events = allEvents
                    print("Loaded basic events: \(baseEvents.count), total with repetitions: \(allEvents.count)")
                }
            }
        }
    }
    // Getting color for event type
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

    // Time formatting
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Enhanced event card
struct EnhancedEventRow: View {
    var event: Event

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator and event type icon
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForEventType(event.type).opacity(0.2))
                        .frame(width: 48, height: 48)

                    Text(event.icon)
                        .font(.title2)
                }

                // Event time
                Text(formatTime(event.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 48)

            // Event information
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

                // Location
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

    // Determining color for event type
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

    // Time formatting
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Preview
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CalendarView()
        }
    }
}
