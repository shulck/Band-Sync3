import Foundation
import FirebaseFirestore

struct ChatRoom: Identifiable {
    var id: String
    var name: String
    var participants: [String] // ID пользователей
    var lastMessage: String?
    var lastMessageDate: Date?
    var isGroupChat: Bool
    
    // Для удобства работы с Firebase
    var asDict: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "participants": participants,
            "isGroupChat": isGroupChat
        ]
        
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
        
        guard let name = data["name"] as? String,
              let participants = data["participants"] as? [String],
              let isGroupChat = data["isGroupChat"] as? Bool else {
            return nil
        }
        
        self.id = document.documentID
        self.name = name
        self.participants = participants
        self.lastMessage = data["lastMessage"] as? String
        self.lastMessageDate = (data["lastMessageDate"] as? Timestamp)?.dateValue()
        self.isGroupChat = isGroupChat
    }
    
    // Обычный инициализатор
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
}
