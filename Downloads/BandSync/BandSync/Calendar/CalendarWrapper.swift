import SwiftUI
import FSCalendar

struct CalendarWrapper: UIViewRepresentable {
    @Binding var selectedDate: Date
    var events: [Event]
    
    // Преобразуем событие в соответствующий цвет
    private func colorForEventType(_ type: String) -> UIColor {
        switch type {
        case "Concert": return .systemRed
        case "Festival": return .systemOrange
        case "Meeting": return .systemYellow
        case "Rehearsal": return .systemGreen
        case "Photo Session": return .systemBlue
        case "Interview": return .systemPurple
        default: return .systemGray
        }
    }
    
    func makeUIView(context: Context) -> FSCalendar {
        let calendar = FSCalendar()
        calendar.delegate = context.coordinator
        calendar.dataSource = context.coordinator
        calendar.scope = .month
        
        // Базовые настройки внешнего вида
        calendar.appearance.headerDateFormat = "MMMM yyyy"
        calendar.appearance.headerTitleColor = UIColor.label
        calendar.appearance.weekdayTextColor = UIColor.secondaryLabel
        calendar.appearance.todayColor = UIColor.systemBlue.withAlphaComponent(0.3)
        calendar.appearance.selectionColor = UIColor.systemBlue
        
        return calendar
    }
    
    func updateUIView(_ uiView: FSCalendar, context: Context) {
        uiView.select(selectedDate)
        uiView.reloadData()
        
        // Обновляем кэш событий в координаторе
        context.coordinator.updateEventsCache(events: events)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, FSCalendarDelegate, FSCalendarDataSource, FSCalendarDelegateAppearance {
        var parent: CalendarWrapper
        private var eventsByDate: [String: [(event: Event, color: UIColor)]] = [:]
        
        init(_ parent: CalendarWrapper) {
            self.parent = parent
            super.init()
            updateEventsCache(events: parent.events)
        }
        
        func updateEventsCache(events: [Event]) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // Очищаем кэш
            eventsByDate.removeAll()
            
            // Заполняем кэш, сразу определяя цвет для каждого события
            for event in events {
                let dateKey = dateFormatter.string(from: event.date)
                let eventColor = parent.colorForEventType(event.type)
                
                if eventsByDate[dateKey] == nil {
                    eventsByDate[dateKey] = [(event, eventColor)]
                } else {
                    eventsByDate[dateKey]?.append((event, eventColor))
                }
            }
        }
        
        // Проверяем, есть ли события на заданную дату
        func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateKey = dateFormatter.string(from: date)
            
            return eventsByDate[dateKey]?.count ?? 0
        }
        
        // Возвращаем цвета для маркеров событий
        func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateKey = dateFormatter.string(from: date)
            
            guard let eventsWithColors = eventsByDate[dateKey], !eventsWithColors.isEmpty else {
                return nil
            }
            
            return eventsWithColors.map { $0.color }
        }
        
        // Обработка выбора даты
        func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
            parent.selectedDate = date
            
            if monthPosition == .previous || monthPosition == .next {
                calendar.setCurrentPage(date, animated: true)
            }
        }
    }
}
