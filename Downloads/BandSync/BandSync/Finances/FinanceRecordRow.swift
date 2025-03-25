import SwiftUI
import FirebaseFirestore

struct FinanceRecordRow: View {
    var record: FinanceRecord
    
    var body: some View {
        HStack {
            Image(systemName: record.type == .income ? "arrow.down" : "arrow.up")
                .foregroundColor(record.type == .income ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(record.description)
                
                HStack {
                    Text(record.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let subcategory = record.subcategory, !subcategory.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(subcategory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let eventTitle = record.eventTitle, !eventTitle.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        NavigationLink(destination: EventLinkDestination(eventId: record.eventId ?? "")) {
                            Text(eventTitle)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(record.formattedAmount)
                    .foregroundColor(record.type == .income ? .green : .red)
                
                Text(formatDate(record.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct EventLinkDestination: View {
    var eventId: String
    @State private var event: Event?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Загрузка события...")
            } else if let event = event {
                EventDetailView(event: event)
            } else {
                Text("Событие не найдено")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            loadEvent()
        }
    }
    
    private func loadEvent() {
        guard !eventId.isEmpty else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("events").document(eventId).getDocument { snapshot, error in
            isLoading = false
            
            if let error = error {
                print("Error loading event: \(error.localizedDescription)")
                return
            }
            
            if let snapshot = snapshot, snapshot.exists {
                let data = snapshot.data() ?? [:]
                self.event = Event(from: data, id: eventId)
            }
        }
    }
}
