import Foundation

class FinanceValidator {
    // Валидирует сумму
    static func validateAmount(_ amount: String) -> Bool {
        // Проверяем, что строка не пустая
        guard !amount.isEmpty else { return false }
        
        // Проверяем формат суммы (допускаются цифры и одна точка)
        let amountRegex = "^\\d+(\\.\\d{1,2})?$"
        let amountPredicate = NSPredicate(format: "SELF MATCHES %@", amountRegex)
        guard amountPredicate.evaluate(with: amount) else { return false }
        
        // Проверяем, что сумма положительная
        guard let doubleAmount = Double(amount), doubleAmount > 0 else { return false }
        
        return true
    }
    
    // Валидирует код валюты
    static func validateCurrency(_ currency: String) -> Bool {
        // Проверяем, что код валюты содержит 3 символа (по стандарту ISO 4217)
        guard currency.count == 3 else { return false }
        
        // Список поддерживаемых валют (можно расширить)
        let supportedCurrencies = ["USD", "EUR", "UAH"]
        
        return supportedCurrencies.contains(currency)
    }
    
    // Валидирует описание
    static func validateDescription(_ description: String) -> Bool {
        // Проверяем, что описание не пустое и не слишком длинное
        return !description.isEmpty && description.count <= 200
    }
    
    // Валидирует категорию
    static func validateCategory(_ category: String, type: FinanceType) -> Bool {
        // Проверяем, что категория не пустая
        guard !category.isEmpty else { return false }
        
        // Списки допустимых категорий
        let incomeCategories = ["Gig", "Merchandise", "Royalties", "Sponsorship", "Other"]
        let expenseCategories = ["Logistics", "Accommodation", "Food", "Equipment", "Promotion", "Fees", "Other"]
        
        // Проверяем, что категория соответствует типу
        switch type {
        case .income:
            return incomeCategories.contains(category)
        case .expense:
            return expenseCategories.contains(category)
        }
    }
    
    // Комплексная валидация финансовой записи
    static func validateFinanceRecord(amount: String, currency: String, description: String, category: String, type: FinanceType) -> (isValid: Bool, error: String?) {
        // Проверяем сумму
        if !validateAmount(amount) {
            return (false, "Пожалуйста, введите корректную сумму")
        }
        
        // Проверяем валюту
        if !validateCurrency(currency) {
            return (false, "Выбрана неподдерживаемая валюта")
        }
        
        // Проверяем описание
        if !validateDescription(description) {
            return (false, "Описание должно быть заполнено и не превышать 200 символов")
        }
        
        // Проверяем категорию
        if !validateCategory(category, type: type) {
            return (false, "Выбрана некорректная категория")
        }
        
        return (true, nil)
    }
}
