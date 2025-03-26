import Foundation
import FirebaseFirestore

enum MessageStatus: String, Codable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    case edited = "edited" // Новый статус для редактированных сообщений
}

struct ChatMessage: Identifiable, Codable {
   var id: String
   var senderId: String
   var senderName: String
   var text: String
   var timestamp: Date
   var isRead: Bool
   var status: MessageStatus = .sent
   
   // Для удобства работы с Firebase
   var asDict: [String: Any] {
       [
           "senderId": senderId,
           "senderName": senderName,
           "text": text,
           "timestamp": Timestamp(date: timestamp),
           "isRead": isRead,
           "status": status.rawValue
       ]
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
   
   // Обычный инициализатор
   init(id: String = UUID().uuidString,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        status: MessageStatus = .sent) {
       self.id = id
       self.senderId = senderId
       self.senderName = senderName
       self.text = text
       self.timestamp = timestamp
       self.isRead = isRead
       self.status = status
   }
}
