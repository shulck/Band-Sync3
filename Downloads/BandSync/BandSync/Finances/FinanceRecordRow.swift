import SwiftUI

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
                        
                        Text(eventTitle)
                            .font(.caption)
                            .foregroundColor(.blue)
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
