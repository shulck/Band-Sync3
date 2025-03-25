import Foundation

class CurrencyConverterService {
    // Синглтон для доступа к сервису
    static let shared = CurrencyConverterService()
    
    // Кэш курсов валют
    private var exchangeRates: [String: [String: Double]] = [:]
    // Дата последнего обновления курсов
    private var lastUpdateDate: Date?
    
    // Базовая валюта по умолчанию
    private var baseCurrency = "USD"
    
    // URL для API обмена валют
    private let apiUrl = "https://api.exchangerate-api.com/v4/latest/"
    
    private init() {
        // Загружаем сохраненные курсы из UserDefaults при инициализации
        loadSavedRates()
    }
    
    // Устанавливает базовую валюту
    func setBaseCurrency(_ currency: String) {
        self.baseCurrency = currency
    }
    
    // Получает текущую базовую валюту
    func getBaseCurrency() -> String {
        return baseCurrency
    }
    
    // Метод для конвертации суммы из одной валюты в другую
    func convert(amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double? {
        // Если валюты совпадают, возвращаем исходную сумму
        if sourceCurrency == targetCurrency {
            return amount
        }
        
        // Проверяем наличие курсов для исходной валюты
        guard let rates = exchangeRates[sourceCurrency] else {
            // Если курсов нет, пробуем обновить их
            updateExchangeRates(for: sourceCurrency)
            return nil
        }
        
        // Проверяем наличие курса для целевой валюты
        guard let rate = rates[targetCurrency] else {
            return nil
        }
        
        // Конвертируем сумму
        return amount * rate
    }
    
    // Асинхронная версия метода конвертации
    func convertAsync(amount: Double, from sourceCurrency: String, to targetCurrency: String) async -> Double? {
        // Если валюты совпадают, возвращаем исходную сумму
        if sourceCurrency == targetCurrency {
            return amount
        }
        
        // Если курсов нет или они устарели, обновляем их
        if exchangeRates[sourceCurrency] == nil || isUpdateNeeded() {
            do {
                try await updateExchangeRatesAsync(for: sourceCurrency)
            } catch {
                print("Error updating exchange rates: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Получаем курсы для исходной валюты
        guard let rates = exchangeRates[sourceCurrency],
              let rate = rates[targetCurrency] else {
            return nil
        }
        
        // Конвертируем сумму
        return amount * rate
    }
    
    // Проверяет, нужно ли обновить курсы
    private func isUpdateNeeded() -> Bool {
        guard let lastUpdate = lastUpdateDate else {
            return true
        }
        
        // Обновляем курсы, если прошло более 24 часов
        let calendar = Calendar.current
        if let dayDifference = calendar.dateComponents([.hour], from: lastUpdate, to: Date()).hour,
           dayDifference >= 24 {
            return true
        }
        
        return false
    }
    
    // Метод для обновления курсов валют
    func updateExchangeRates(for currency: String, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(apiUrl)\(currency)") else {
            completion?(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let ratesResponse = try? JSONDecoder().decode(ExchangeRatesResponse.self, from: data) else {
                completion?(false)
                return
            }
            
            // Сохраняем полученные курсы
            self.exchangeRates[currency] = ratesResponse.rates
            self.lastUpdateDate = Date()
            
            // Сохраняем курсы в UserDefaults
            self.saveRates()
            
            completion?(true)
        }.resume()
    }
    
    // Асинхронный метод для обновления курсов
    func updateExchangeRatesAsync(for currency: String) async throws {
        guard let url = URL(string: "\(apiUrl)\(currency)") else {
            throw NSError(domain: "CurrencyConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let ratesResponse = try JSONDecoder().decode(ExchangeRatesResponse.self, from: data)
        
        // Сохраняем полученные курсы
        self.exchangeRates[currency] = ratesResponse.rates
        self.lastUpdateDate = Date()
        
        // Сохраняем курсы в UserDefaults
        self.saveRates()
    }
    
    // Сохраняет курсы валют в UserDefaults
    private func saveRates() {
        let defaults = UserDefaults.standard
        
        if let encoded = try? JSONEncoder().encode(exchangeRates) {
            defaults.set(encoded, forKey: "savedExchangeRates")
        }
        
        defaults.set(lastUpdateDate, forKey: "lastExchangeRatesUpdate")
    }
    
    // Загружает сохраненные курсы из UserDefaults
    private func loadSavedRates() {
        let defaults = UserDefaults.standard
        
        if let savedRates = defaults.object(forKey: "savedExchangeRates") as? Data,
           let decodedRates = try? JSONDecoder().decode([String: [String: Double]].self, from: savedRates) {
            self.exchangeRates = decodedRates
        }
        
        self.lastUpdateDate = defaults.object(forKey: "lastExchangeRatesUpdate") as? Date
    }
}

// Структура для декодирования ответа API
struct ExchangeRatesResponse: Codable {
    let base: String
    let rates: [String: Double]
}
