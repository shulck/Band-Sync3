import SwiftUI

struct RecurrenceView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isRecurring: Bool
    @Binding var recurrenceType: RecurrenceHelper.RecurrenceType?
    @Binding var recurrenceInterval: Int
    @Binding var recurrenceEndDate: Date?
    @Binding var selectedDaysOfWeek: [Int]?
    
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date().addingTimeInterval(60*60*24*30) // +30 days
    
    let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Repeat Settings")) {
                    Toggle("Repeat Event", isOn: $isRecurring)
                        .onChange(of: isRecurring) { newValue in
                            if newValue && recurrenceType == nil {
                                recurrenceType = .weekly
                            }
                        }
                }
                
                if isRecurring {
                    Section(header: Text("Frequency")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Repeat every")
                                .font(.headline)
                            
                            HStack {
                                Stepper(value: $recurrenceInterval, in: 1...30) {
                                    Text("\(recurrenceInterval) \(intervalLabel)")
                                }
                            }
                            
                            Picker("Repeat Type", selection: $recurrenceType) {
                                Text("Daily").tag(Optional(RecurrenceHelper.RecurrenceType.daily))
                                Text("Weekly").tag(Optional(RecurrenceHelper.RecurrenceType.weekly))
                                Text("Monthly").tag(Optional(RecurrenceHelper.RecurrenceType.monthly))
                                Text("Yearly").tag(Optional(RecurrenceHelper.RecurrenceType.yearly))
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 8)
                            
                            if recurrenceType == .weekly {
                                Text("Repeat on days")
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 8) {
                                    ForEach(0..<7) { index in
                                        Button(action: {
                                            toggleDay(index + 1)
                                        }) {
                                            Text(weekdays[index])
                                                .frame(width: 36, height: 36)
                                                .background(isDaySelected(index + 1) ? Color.blue : Color.clear)
                                                .foregroundColor(isDaySelected(index + 1) ? .white : .primary)
                                                .cornerRadius(18)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.gray, lineWidth: isDaySelected(index + 1) ? 0 : 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    Section(header: Text("End Repeat")) {
                        Toggle("Set End Date", isOn: $hasEndDate)
                            .onChange(of: hasEndDate) { newValue in
                                recurrenceEndDate = newValue ? endDate : nil
                            }
                            .onChange(of: recurrenceEndDate) { newValue in
                                hasEndDate = newValue != nil
                                if let date = newValue {
                                    endDate = date
                                }
                            }
                        
                        if hasEndDate {
                            DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                                .onChange(of: endDate) { newValue in
                                    recurrenceEndDate = newValue
                                }
                        }
                    }
                    
                    Section {
                        Text("This event will repeat \(recurrenceSummary)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Recurrence")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    if !isRecurring {
                        recurrenceType = nil
                        recurrenceInterval = 1
                        recurrenceEndDate = nil
                        selectedDaysOfWeek = nil
                    } else if recurrenceType == .weekly && (selectedDaysOfWeek == nil || selectedDaysOfWeek!.isEmpty) {
                        selectedDaysOfWeek = [Calendar.current.component(.weekday, from: Date())]
                    }
                    
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                hasEndDate = recurrenceEndDate != nil
                if let date = recurrenceEndDate {
                    endDate = date
                }
                
                // Инициализация дней недели, если не выбраны
                if recurrenceType == .weekly && (selectedDaysOfWeek == nil || selectedDaysOfWeek!.isEmpty) {
                    selectedDaysOfWeek = [Calendar.current.component(.weekday, from: Date())]
                }
            }
        }
    }
    
    private var intervalLabel: String {
        guard let type = recurrenceType else { return "" }
        
        switch type {
        case .daily:
            return recurrenceInterval == 1 ? "day" : "days"
        case .weekly:
            return recurrenceInterval == 1 ? "week" : "weeks"
        case .monthly:
            return recurrenceInterval == 1 ? "month" : "months"
        case .yearly:
            return recurrenceInterval == 1 ? "year" : "years"
        }
    }
    
    private var recurrenceSummary: String {
        guard let type = recurrenceType else { return "" }
        
        var summary = "every "
        if recurrenceInterval > 1 {
            summary += "\(recurrenceInterval) "
        }
        
        switch type {
        case .daily:
            summary += recurrenceInterval == 1 ? "day" : "days"
        case .weekly:
            summary += recurrenceInterval == 1 ? "week" : "weeks"
            
            if let days = selectedDaysOfWeek, !days.isEmpty {
                summary += " on " + days.sorted().map { weekdayName($0) }.joined(separator: ", ")
            }
        case .monthly:
            summary += recurrenceInterval == 1 ? "month" : "months"
        case .yearly:
            summary += recurrenceInterval == 1 ? "year" : "years"
        }
        
        if let endDate = recurrenceEndDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            summary += " until \(formatter.string(from: endDate))"
        } else {
            summary += " with no end date"
        }
        
        return summary
    }
    
    private func isDaySelected(_ day: Int) -> Bool {
        return selectedDaysOfWeek?.contains(day) ?? false
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDaysOfWeek == nil {
            selectedDaysOfWeek = []
        }
        
        if let index = selectedDaysOfWeek?.firstIndex(of: day) {
            selectedDaysOfWeek?.remove(at: index)
        } else {
            selectedDaysOfWeek?.append(day)
        }
    }
    
    private func weekdayName(_ weekday: Int) -> String {
        let calendar = Calendar.current
        return weekdays[weekday - 1]
    }
}
