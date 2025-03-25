import Foundation

enum FinanceError: Error {
    case invalidAmount
    case invalidCurrency
    case conversionFailed
    case networkError(Error)
    case databaseError(Error)
    case imageUploadError(Error)
    case missingData
    case unauthorized
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidAmount:
            return "Указана некорректная сумма"
        case .invalidCurrency:
            return "Указана некорректная валюта"
        case .conversionFailed:
            return "Не удалось выполнить конвертацию валют"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Ошибка базы данных: \(error.localizedDescription)"
        case .imageUploadError(let error):
            return "Ошибка загрузки изображения: \(error.localizedDescription)"
        case .missingData:
            return "Отсутствуют необходимые данные"
        case .unauthorized:
            return "У вас нет доступа к этим данным"
        case .unknown:
            return "Произошла неизвестная ошибка"
        }
    }
}
