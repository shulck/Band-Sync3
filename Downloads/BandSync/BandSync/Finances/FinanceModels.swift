import Foundation
import FirebaseFirestore

// Тип финансовой операции
enum FinanceType: String, Codable {
    case income, expense
}

// Структура финансовой записи
struct FinanceRecord: Identifiable {
    var id: String
    var type: FinanceType
    var amount: Double
    var currency: String
    var description: String
    var category: String
    var date: Date
    var receiptImageURL: String?
    
    // Новые поля
    var eventId: String? // Связь с событием
    var eventTitle: String? // Название события для отображения
    var subcategory: String? // Подкатегория (особенно для мерча)
    var tags: [String]? // Теги для быстрого поиска и фильтрации
    
    // Вычисляемое свойство для отображения валюты с суммой
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}
