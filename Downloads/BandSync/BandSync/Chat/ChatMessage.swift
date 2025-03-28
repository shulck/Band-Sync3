import Foundation
import FirebaseFirestore

enum MessageStatus: String, Codable, Equatable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    case edited = "edited"
    
    // Получение статуса из строки
    static func fromString(_ statusString: String) -> MessageStatus {
        return MessageStatus(rawValue: statusString) ?? .sent
    }
}

struct ReplyData: Codable, Equatable {
    var messageId: String
    var text: String
    var senderName: String
    var senderId: String
    
    var asDict: [String: Any] {
        return [
            "messageId": messageId,
            "text": text,
            "senderName": senderName,
            "senderId": senderId
        ]
    }
    
    static func fromDict(_ dict: [String: Any]) -> ReplyData? {
        guard let messageId = dict["messageId"] as? String,
              let text = dict["text"] as? String,
              let senderName = dict["senderName"] as? String,
              let senderId = dict["senderId"] as? String else {
            return nil
        }
        
        return ReplyData(
            messageId: messageId,
            text: text,
            senderName: senderName,
            senderId: senderId
        )
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var isRead: Bool
    var status: MessageStatus
    var replyTo: ReplyData?
    
    // Для сравнения сообщений
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.isRead == rhs.isRead &&
               lhs.status == rhs.status &&
               lhs.replyTo?.messageId == rhs.replyTo?.messageId
    }
    
    // Для удобства работы с Firebase
    var asDict: [String: Any] {
        var dict: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": Timestamp(date: timestamp),
            "isRead": isRead,
            "status": status.rawValue
        ]
        
        // Добавляем данные об ответе, если есть
        if let replyTo = replyTo {
            dict["replyTo"] = replyTo.asDict
        }
        
        // Убедимся, что все поля существуют и имеют правильный формат
        if dict["senderId"] == nil { dict["senderId"] = "" }
        if dict["senderName"] == nil { dict["senderName"] = "" }
        if dict["text"] == nil { dict["text"] = "" }
        if dict["timestamp"] == nil { dict["timestamp"] = Timestamp(date: Date()) }
        if dict["isRead"] == nil { dict["isRead"] = false }
        if dict["status"] == nil { dict["status"] = MessageStatus.sent.rawValue }
        
        return dict
    }
    
    // Инициализатор из Firebase документа
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        // Извлечение основных полей
        guard let senderId = data["senderId"] as? String,
              let text = data["text"] as? String else {
            print("❌ Missing required fields in message document: \(document.documentID)")
            return nil
        }
        
        // Обработка имени отправителя
        let senderName = data["senderName"] as? String ?? "Unknown"
        
        // Обработка временной метки
        let timestamp: Date
        if let timestampData = data["timestamp"] as? Timestamp {
            timestamp = timestampData.dateValue()
        } else {
            // Если нет временной метки, используем текущее время
            print("⚠️ Missing timestamp for message \(document.documentID), using current time")
            timestamp = Date()
        }
        
        // Статус прочтения
        let isRead = data["isRead"] as? Bool ?? false
        
        // Статус сообщения
        let status: MessageStatus
        if let statusString = data["status"] as? String {
            status = MessageStatus.fromString(statusString)
        } else {
            // По умолчанию считаем, что сообщение отправлено
            status = .sent
        }
        
        // Данные об ответе на сообщение
        var replyTo: ReplyData?
        if let replyData = data["replyTo"] as? [String: Any] {
            replyTo = ReplyData.fromDict(replyData)
        }
        
        self.id = document.documentID
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.status = status
        self.replyTo = replyTo
        
        print("✅ Successfully parsed message: \(id) from \(senderName)")
    }
    
    // Обычный инициализатор
    init(id: String = UUID().uuidString,
         senderId: String,
         senderName: String,
         text: String,
         timestamp: Date = Date(),
         isRead: Bool = false,
         status: MessageStatus = .sent,
         replyTo: ReplyData? = nil) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.status = status
        self.replyTo = replyTo
    }
    
    // Метод для создания копии с обновленным статусом
    func withUpdatedStatus(_ newStatus: MessageStatus) -> ChatMessage {
        return ChatMessage(
            id: self.id,
            senderId: self.senderId,
            senderName: self.senderName,
            text: self.text,
            timestamp: self.timestamp,
            isRead: self.isRead,
            status: newStatus,
            replyTo: self.replyTo
        )
    }
    
    // Метод для создания копии с обновленным текстом
    func withUpdatedText(_ newText: String) -> ChatMessage {
        return ChatMessage(
            id: self.id,
            senderId: self.senderId,
            senderName: self.senderName,
            text: newText,
            timestamp: self.timestamp,
            isRead: self.isRead,
            status: .edited,
            replyTo: self.replyTo
        )
    }
    
    // Проверка, является ли сообщение системным
    var isSystemMessage: Bool {
        return senderId == "system"
    }
}
