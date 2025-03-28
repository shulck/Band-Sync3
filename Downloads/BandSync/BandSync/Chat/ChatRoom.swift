import Foundation
import FirebaseFirestore

struct ChatRoom: Identifiable, Equatable {
    var id: String
    var name: String
    var participants: [String] // ID пользователей
    var lastMessage: String?
    var lastMessageDate: Date?
    var isGroupChat: Bool
    
    // Для сравнения чатов
    static func == (lhs: ChatRoom, rhs: ChatRoom) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Для удобства работы с Firebase
    var asDict: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "participants": participants,
            "isGroupChat": isGroupChat
        ]
        
        // Добавляем опциональные поля, только если они существуют
        if let lastMessage = lastMessage {
            dict["lastMessage"] = lastMessage
        }
        
        if let lastMessageDate = lastMessageDate {
            dict["lastMessageDate"] = Timestamp(date: lastMessageDate)
        }
        
        return dict
    }
    
    // Инициализатор из Firebase документа
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        // Извлекаем необходимые поля, логируя процесс для отладки
        print("🔍 Parsing chat document: \(document.documentID)")
        
        guard let name = data["name"] as? String else {
            print("❌ Missing name in chat document: \(document.documentID)")
            return nil
        }
        
        guard let participants = data["participants"] as? [String] else {
            print("❌ Missing participants in chat document: \(document.documentID)")
            return nil
        }
        
        guard let isGroupChat = data["isGroupChat"] as? Bool else {
            print("❌ Missing isGroupChat in chat document: \(document.documentID), defaulting to false")
            // Обязательно добавляем return, чтобы выйти из блока guard
            return nil
        }
        
        self.id = document.documentID
        self.name = name
        self.participants = participants
        self.lastMessage = data["lastMessage"] as? String
        self.lastMessageDate = (data["lastMessageDate"] as? Timestamp)?.dateValue()
        self.isGroupChat = data["isGroupChat"] as? Bool ?? false
        
        // Дополнительное логирование для отладки
        print("✅ Successfully parsed chat: \(id), name: \(name), participants: \(participants.count)")
    }
    
    // Стандартный инициализатор
    init(id: String = UUID().uuidString,
         name: String,
         participants: [String],
         lastMessage: String? = nil,
         lastMessageDate: Date? = nil,
         isGroupChat: Bool = false) {
        self.id = id
        self.name = name
        self.participants = participants
        self.lastMessage = lastMessage
        self.lastMessageDate = lastMessageDate
        self.isGroupChat = isGroupChat
    }
    
    // Метод для добавления участника
    func addingParticipant(_ userId: String) -> ChatRoom {
        var updatedParticipants = self.participants
        if !updatedParticipants.contains(userId) {
            updatedParticipants.append(userId)
        }
        
        return ChatRoom(
            id: self.id,
            name: self.name,
            participants: updatedParticipants,
            lastMessage: self.lastMessage,
            lastMessageDate: self.lastMessageDate,
            isGroupChat: self.isGroupChat
        )
    }
    
    // Метод для удаления участника
    func removingParticipant(_ userId: String) -> ChatRoom {
        let updatedParticipants = self.participants.filter { $0 != userId }
        
        return ChatRoom(
            id: self.id,
            name: self.name,
            participants: updatedParticipants,
            lastMessage: self.lastMessage,
            lastMessageDate: self.lastMessageDate,
            isGroupChat: self.isGroupChat
        )
    }
    
    // Метод для обновления названия чата
    func withUpdatedName(_ newName: String) -> ChatRoom {
        return ChatRoom(
            id: self.id,
            name: newName,
            participants: self.participants,
            lastMessage: self.lastMessage,
            lastMessageDate: self.lastMessageDate,
            isGroupChat: self.isGroupChat
        )
    }
    
    // Проверка, содержит ли чат конкретного участника
    func containsParticipant(_ userId: String) -> Bool {
        return participants.contains(userId)
    }
    
    // Генерация названия чата для личных чатов
    // В случае, если нужно генерировать название на основе имени собеседника
    func displayNameForUser(currentUserId: String, usersMap: [String: String]) -> String {
        // Для группового чата всегда используем заданное имя
        if isGroupChat {
            return name
        }
        
        // Для личного чата, находим собеседника
        for participantId in participants {
            if participantId != currentUserId, let participantName = usersMap[participantId] {
                return participantName
            }
        }
        
        // Если не найдено, используем стандартное имя
        return name
    }
}
