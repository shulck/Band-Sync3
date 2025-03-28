import Foundation
import FirebaseFirestore

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
    case edited
}

struct ChatMessage: Identifiable, Codable {
    var id: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var isRead: Bool
    var status: MessageStatus
    
    init(
        id: String = UUID().uuidString,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        status: MessageStatus = .sent
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.status = status
    }
    
    // Инициализатор из Firebase документа
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let text = data["text"] as? String,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.id = document.documentID
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = data["isRead"] as? Bool ?? false
        
        if let statusString = data["status"] as? String,
           let messageStatus = MessageStatus(rawValue: statusString) {
            self.status = messageStatus
        } else {
            self.status = .sent
        }
    }
}
