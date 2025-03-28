import Foundation
import FirebaseFirestore

struct EventContact: Codable {
    var name: String
    var phone: String
    var email: String
}

struct Hotel: Codable {
    var address: String
    var checkIn: String
    var checkOut: String
}

struct DailyScheduleItem: Codable, Identifiable {
    var id = UUID().uuidString
    var time: String
    var activity: String
}

struct Event: Identifiable, Codable {
    var id: String
    var title: String
    var date: Date
    var type: String
    var status: String
    var location: String
    var organizer: EventContact
    var coordinator: EventContact
    var hotel: Hotel
    var fee: String
    var setlist: [String]
    var setlistId: String?      // Добавьте это поле
    var setlistName: String?    // И это поле
    var notes: String
    var schedule: [DailyScheduleItem]
    var isPersonal: Bool = false
    var groupId: String = ""
    
    // Поля для повторяющихся событий
    var isRecurring: Bool = false
    var recurrenceType: String? = nil // "daily", "weekly", "monthly", "yearly"
    var recurrenceEndDate: Date? = nil
    var recurrenceInterval: Int = 1
    var recurrenceParentId: String? = nil
    var recurrenceDaysOfWeek: [Int]? = nil // для еженедельных повторений (1 = понедельник, 7 = воскресенье)

    enum CodingKeys: String, CodingKey {
        case id, title, date, type, status, location, organizer, coordinator, hotel, fee, setlist, notes, schedule, isPersonal
        case isRecurring, recurrenceType, recurrenceEndDate, recurrenceInterval, recurrenceParentId, recurrenceDaysOfWeek
        case groupId
    }

    init(id: String = UUID().uuidString,
         title: String,
         date: Date,
         type: String,
         status: String,
         location: String,
         organizer: EventContact,
         coordinator: EventContact,
         hotel: Hotel,
         fee: String,
         setlist: [String] = [],
         notes: String = "",
         isPersonal: Bool = false,
         schedule: [DailyScheduleItem] = [],
         isRecurring: Bool = false,
         recurrenceType: String? = nil,
         recurrenceEndDate: Date? = nil,
         recurrenceInterval: Int = 1,
         recurrenceParentId: String? = nil,
         groupId: String = "",
         recurrenceDaysOfWeek: [Int]? = nil) {
        self.id = id
        self.groupId = groupId
        self.title = title
        self.date = date
        self.type = type
        self.status = status
        self.location = location
        self.organizer = organizer
        self.coordinator = coordinator
        self.hotel = hotel
        self.fee = fee
        self.setlist = setlist
        self.notes = notes
        self.schedule = schedule
        self.isPersonal = isPersonal
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceParentId = recurrenceParentId
        self.recurrenceDaysOfWeek = recurrenceDaysOfWeek
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let timestamp = try container.decode(Timestamp.self, forKey: .date)
        date = timestamp.dateValue()
        type = try container.decode(String.self, forKey: .type)
        status = try container.decode(String.self, forKey: .status)
        location = try container.decode(String.self, forKey: .location)
        organizer = try container.decode(EventContact.self, forKey: .organizer)
        coordinator = try container.decode(EventContact.self, forKey: .coordinator)
        hotel = try container.decode(Hotel.self, forKey: .hotel)
        fee = try container.decode(String.self, forKey: .fee)
        setlist = try container.decode([String].self, forKey: .setlist)
        notes = try container.decode(String.self, forKey: .notes)
        schedule = try container.decode([DailyScheduleItem].self, forKey: .schedule)
        isPersonal = try container.decodeIfPresent(Bool.self, forKey: .isPersonal) ?? false
        
        // Декодирование полей повторяющихся событий
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        recurrenceType = try container.decodeIfPresent(String.self, forKey: .recurrenceType)
        if let recurrenceEndTimestamp = try container.decodeIfPresent(Timestamp.self, forKey: .recurrenceEndDate) {
            recurrenceEndDate = recurrenceEndTimestamp.dateValue()
        }
        recurrenceInterval = try container.decodeIfPresent(Int.self, forKey: .recurrenceInterval) ?? 1
        recurrenceParentId = try container.decodeIfPresent(String.self, forKey: .recurrenceParentId)
        recurrenceDaysOfWeek = try container.decodeIfPresent([Int].self, forKey: .recurrenceDaysOfWeek)
    }

    // Convenient initializer for creating an object from Firestore data
    init?(from data: [String: Any], id: String) {
        guard let title = data["title"] as? String,
              let timestamp = data["date"] as? Timestamp,
              let type = data["type"] as? String,
              let status = data["status"] as? String,
              let location = data["location"] as? String,
              let organizerData = data["organizer"] as? [String: Any],
              let organizerName = organizerData["name"] as? String,
              let organizerPhone = organizerData["phone"] as? String,
              let organizerEmail = organizerData["email"] as? String,
              let coordinatorData = data["coordinator"] as? [String: Any],
              let coordinatorName = coordinatorData["name"] as? String,
              let coordinatorPhone = coordinatorData["phone"] as? String,
              let coordinatorEmail = coordinatorData["email"] as? String,
              let hotelData = data["hotel"] as? [String: Any],
              let hotelAddress = hotelData["address"] as? String,
              let hotelCheckIn = hotelData["checkIn"] as? String,
              let hotelCheckOut = hotelData["checkOut"] as? String,
              let fee = data["fee"] as? String
        else { return nil }

        self.id = id
        self.title = title
        self.date = timestamp.dateValue()
        self.type = type
        self.status = status
        self.location = location

        self.organizer = EventContact(
            name: organizerName,
            phone: organizerPhone,
            email: organizerEmail
        )

        self.coordinator = EventContact(
            name: coordinatorName,
            phone: coordinatorPhone,
            email: coordinatorEmail
        )

        self.hotel = Hotel(
            address: hotelAddress,
            checkIn: hotelCheckIn,
            checkOut: hotelCheckOut
        )

        self.fee = fee
        self.setlist = data["setlist"] as? [String] ?? []
        self.notes = data["notes"] as? String ?? ""
        self.isPersonal = data["isPersonal"] as? Bool ?? false

        // Парсинг расписания
        var scheduleItems: [DailyScheduleItem] = []
        if let scheduleData = data["schedule"] as? [[String: Any]] {
            for itemData in scheduleData {
                if let time = itemData["time"] as? String,
                   let activity = itemData["activity"] as? String {
                    scheduleItems.append(DailyScheduleItem(time: time, activity: activity))
                }
            }
        }
        self.schedule = scheduleItems
        
        // Парсинг полей повторяющегося события
        self.isRecurring = data["isRecurring"] as? Bool ?? false
        self.recurrenceType = data["recurrenceType"] as? String
        self.recurrenceEndDate = (data["recurrenceEndDate"] as? Timestamp)?.dateValue()
        self.recurrenceInterval = data["recurrenceInterval"] as? Int ?? 1
        self.recurrenceParentId = data["recurrenceParentId"] as? String
        self.recurrenceDaysOfWeek = data["recurrenceDaysOfWeek"] as? [Int]
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "groupId": groupId,
            "title": title,
            "date": Timestamp(date: date),
            "type": type,
            "status": status,
            "location": location,
            "fee": fee,
            "notes": notes,
            "setlist": setlist,
            "isPersonal": isPersonal,
            "organizer": [
                "name": organizer.name,
                "phone": organizer.phone,
                "email": organizer.email
            ],
            "coordinator": [
                "name": coordinator.name,
                "phone": coordinator.phone,
                "email": coordinator.email
            ],
            "hotel": [
                "address": hotel.address,
                "checkIn": hotel.checkIn,
                "checkOut": hotel.checkOut
            ],
            "schedule": schedule.map { ["time": $0.time, "activity": $0.activity, "id": $0.id] }
        ]
        
        // Добавляем поля для повторяющихся событий
        dict["isRecurring"] = isRecurring

        if isRecurring {
            if let recurrenceType = recurrenceType {
                dict["recurrenceType"] = recurrenceType
            }
            
            if let recurrenceEndDate = recurrenceEndDate {
                dict["recurrenceEndDate"] = Timestamp(date: recurrenceEndDate)
            }
            
            dict["recurrenceInterval"] = recurrenceInterval
            
            if let recurrenceParentId = recurrenceParentId {
                dict["recurrenceParentId"] = recurrenceParentId
            }
            
            if let recurrenceDaysOfWeek = recurrenceDaysOfWeek {
                dict["recurrenceDaysOfWeek"] = recurrenceDaysOfWeek
            }
        }
        
        return dict
    }

    // Возвращает иконку в зависимости от типа события
    var icon: String {
        switch type {
        case "Concert": return "🎤"
        case "Festival": return "🎪"
        case "Meeting": return "🤝"
        case "Rehearsal": return "🎸"
        case "Photo Session": return "📷"
        case "Interview": return "🎙"
        default: return "📅"
        }
    }

    // Возвращает цвет в зависимости от типа события
    var typeColor: String {
        switch type {
        case "Concert": return "red"
        case "Festival": return "orange"
        case "Meeting": return "yellow"
        case "Rehearsal": return "green"
        case "Photo Session": return "blue"
        case "Interview": return "purple"
        default: return "gray"
        }
    }
}
