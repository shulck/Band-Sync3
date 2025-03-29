import Foundation

class RecurrenceHelper {

    // Types of recurrence
    enum RecurrenceType: String, CaseIterable, Identifiable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"

        var id: String { self.rawValue }

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }

    // Generate dates for recurring events
    static func generateRecurringDates(
        startDate: Date,
        endDate: Date?,
        type: RecurrenceType,
        interval: Int,
        daysOfWeek: [Int]? = nil,
        limit: Int = 50 // Limit on the number of events created
    ) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current

        // Determine the final date (or use a large interval if date not specified)
        let finalEndDate = endDate ?? calendar.date(byAdding: .year, value: 2, to: startDate)!

        // Use startDate as the base date
        var currentDate = startDate

        // Add the start date
        dates.append(startDate)

        // Generate the next dates depending on the type of recurrence
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
                // If there are selected days of the week
                if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                    // Move to the next week
                    dateComponent = DateComponents(day: 1)

                    while dates.count < limit {
                        currentDate = calendar.date(byAdding: dateComponent, to: currentDate)!

                        // If we moved to another week considering the interval
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

                        // If we exceeded the end date, exit
                        if currentDate > finalEndDate {
                            break
                        }
                    }
                } else {
                    // Simple weekly recurrence
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

    // Function to get all dates of recurring events for a given period
    static func getRecurringEventDates(event: Event, startDate: Date, endDate: Date) -> [Date] {
        guard event.isRecurring,
              let recurrenceType = event.recurrenceType,
              let type = RecurrenceType(rawValue: recurrenceType) else {
            return [event.date] // If not recurring, return only the event date
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
