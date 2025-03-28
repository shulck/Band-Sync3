import Foundation

class RecurrenceHelper {
    
    // Типы повторений
    enum RecurrenceType: String, CaseIterable, Identifiable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .daily: return "Ежедневно"
            case .weekly: return "Еженедельно"
            case .monthly: return "Ежемесячно"
            case .yearly: return "Ежегодно"
            }
        }
    }
    
    // Генерирует даты для повторяющегося события
    static func generateRecurringDates(
        startDate: Date,
        endDate: Date?,
        type: RecurrenceType,
        interval: Int,
        daysOfWeek: [Int]? = nil,
        limit: Int = 50 // Ограничение на количество создаваемых событий
    ) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        
        // Определяем крайнюю дату (или используем большой интервал, если дата не указана)
        let finalEndDate = endDate ?? calendar.date(byAdding: .year, value: 2, to: startDate)!
        
        // Используем startDate как базовую дату
        var currentDate = startDate
        
        // Добавляем начальную дату
        dates.append(startDate)
        
        // Генерируем следующие даты в зависимости от типа повторения
        while currentDate < finalEndDate && dates.count < limit {
            var dateComponent: DateComponents
            
            switch type {
            case .daily:
                dateComponent = DateComponents(day: interval)
                if let nextDate = calendar.date(byAdding: dateComponent, to: currentDate) {
                    currentDate = nextDate
                    if currentDate <= finalEndDate {
                        dates.append(currentDate)
                    }
                }
                
            case .weekly:
                // Если есть выбранные дни недели
                if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                    // Переходим к следующей неделе
                    dateComponent = DateComponents(day: 1)
                    
                    while dates.count < limit {
                        currentDate = calendar.date(byAdding: dateComponent, to: currentDate)!
                        
                        // Если перешли на другую неделю с учетом интервала
                        let weekOfYear = calendar.component(.weekOfYear, from: startDate)
                        let currentWeekOfYear = calendar.component(.weekOfYear, from: currentDate)
                        let weekDifference = currentWeekOfYear - weekOfYear
                        
                        if weekDifference > 0 && weekDifference % interval == 0 {
                            let currentWeekday = calendar.component(.weekday, from: currentDate)
                            
                            if daysOfWeek.contains(currentWeekday) {
                                if currentDate <= finalEndDate {
                                    dates.append(currentDate)
                                } else {
                                    break
                                }
                            }
                        }
                        
                        // Если превысили конечную дату, выходим
                        if currentDate > finalEndDate {
                            break
                        }
                    }
                } else {
                    // Простое еженедельное повторение
                    dateComponent = DateComponents(day: 7 * interval)
                    while dates.count < limit {
                        if let nextDate = calendar.date(byAdding: dateComponent, to: currentDate) {
                            currentDate = nextDate
                            if currentDate <= finalEndDate {
                                dates.append(currentDate)
                            } else {
                                break
                            }
                        } else {
                            break
                        }
                    }
                }
                
            case .monthly:
                dateComponent = DateComponents(month: interval)
                while dates.count < limit {
                    if let nextDate = calendar.date(byAdding: dateComponent, to: currentDate) {
                        currentDate = nextDate
                        if currentDate <= finalEndDate {
                            dates.append(currentDate)
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                
            case .yearly:
                dateComponent = DateComponents(year: interval)
                while dates.count < limit {
                    if let nextDate = calendar.date(byAdding: dateComponent, to: currentDate) {
                        currentDate = nextDate
                        if currentDate <= finalEndDate {
                            dates.append(currentDate)
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
            }
        }
        
        return dates
    }
    
    // Функция для получения всех дат повторяющихся событий на заданный период
    static func getRecurringEventDates(event: Event, startDate: Date, endDate: Date) -> [Date] {
        guard event.isRecurring,
              let recurrenceType = event.recurrenceType,
              let type = RecurrenceType(rawValue: recurrenceType) else {
            return [event.date] // Если не повторяющееся, возвращаем только дату события
        }
        
        return generateRecurringDates(
            startDate: event.date,
            endDate: event.recurrenceEndDate,
            type: type,
            interval: event.recurrenceInterval,
            daysOfWeek: event.recurrenceDaysOfWeek
        ).filter { $0 >= startDate && $0 <= endDate }
    }
}
