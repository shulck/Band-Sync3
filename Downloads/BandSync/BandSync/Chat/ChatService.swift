import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var chatRooms: [ChatRoom] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var hasMoreMessages = false

    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    private var chatRoomsListener: ListenerRegistration?
    private var lastMessage: QueryDocumentSnapshot?

    private let messagesPerPage = 20

    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    var currentUserName: String {
        return Auth.auth().currentUser?.displayName ?? "User"
    }

    func fetchMessages(for chatRoomId: String) {
        isLoading = true
        messagesListener?.remove()

        print("Setting up messages listener for chat ID: \(chatRoomId)")

        // Устанавливаем слушатель напрямую - более простой подход
        messagesListener = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    print("❌ Error loading messages: \(error.localizedDescription)")
                    self.errorMessage = "Error loading messages: \(error.localizedDescription)"
                    return
                }

                // Для отладки
                print("📩 Received message snapshot - count: \(querySnapshot?.documents.count ?? 0)")

                let allMessages = querySnapshot?.documents.compactMap { document -> ChatMessage? in
                    let message = ChatMessage(document: document)
                    if message != nil {
                        print("✅ Message loaded: \(message!.text) from \(message!.senderName)")
                    } else {
                        print("❌ Failed to parse message from document: \(document.documentID)")
                    }
                    return message
                } ?? []

                // Сортируем и обновляем UI
                self.messages = allMessages.sorted { $0.timestamp < $1.timestamp }
                self.hasMoreMessages = allMessages.count >= self.messagesPerPage

                print("🔄 Updated messages array - new count: \(self.messages.count)")
            }
    }

    func loadMoreMessages(for chatRoomId: String) {
        guard let lastMessage = self.lastMessage else {
            self.hasMoreMessages = false
            return
        }

        isLoading = true

        db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .start(afterDocument: lastMessage)
            .limit(to: messagesPerPage)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Error loading more messages: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.hasMoreMessages = false
                    return
                }

                self.lastMessage = documents.last

                let olderMessages = documents.compactMap { ChatMessage(document: $0) }
                    .sorted { $0.timestamp < $1.timestamp }

                self.messages.insert(contentsOf: olderMessages, at: 0)
                self.hasMoreMessages = documents.count >= self.messagesPerPage
            }
    }

    func sendMessage(text: String, in chatRoomId: String) {
        guard let currentUserId = currentUserId,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔵 Attempting to send message: \"\(trimmedText)\" to chat: \(chatRoomId)")

        let newMessageId = UUID().uuidString

        // Создаем временное сообщение для локального отображения
        let tempMessage = ChatMessage(
            id: newMessageId,
            senderId: currentUserId,
            senderName: currentUserName,
            text: trimmedText,
            timestamp: Date(),
            isRead: false,
            status: .sending
        )

        // Добавляем сообщение локально
        DispatchQueue.main.async {
            self.messages.append(tempMessage)
            print("➕ Added temporary message to local array: \(newMessageId)")
        }

        // Подготавливаем данные для Firebase
        let messageData: [String: Any] = [
            "senderId": currentUserId,
            "senderName": currentUserName,
            "text": trimmedText,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "status": MessageStatus.sent.rawValue
        ]

        // Отправка в Firebase
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(newMessageId)

        print("🔹 Sending message to Firebase: \(newMessageId)")

        messageRef.setData(messageData) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Error sending message: \(error.localizedDescription)")

                // Обновляем статус локального сообщения при ошибке
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == newMessageId }) {
                        self.messages[index].status = .failed
                        print("⚠️ Updated message status to failed: \(newMessageId)")
                    }
                }
            } else {
                print("✅ Message sent successfully: \(newMessageId)")

                // Обновляем статус локального сообщения при успехе
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == newMessageId }) {
                        self.messages[index].status = .sent
                        print("✓ Updated message status to sent: \(newMessageId)")
                    }
                }

                // Обновляем информацию о последнем сообщении в чате
                self.updateChatLastMessage(chatRoomId: chatRoomId, text: trimmedText, messageId: newMessageId)
            }
        }
    }

    // Новый метод для проверки существования чата
    private func checkChatExists(_ chatRoomId: String, completion: @escaping (Bool) -> Void) {
        let chatRef = db.collection("chatRooms").document(chatRoomId)

        chatRef.getDocument { [weak self] document, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                print("Error checking chat: \(error.localizedDescription)")
                completion(false)
                return
            }

            if let document = document, document.exists {
                // Проверяем, является ли текущий пользователь участником
                if let data = document.data(),
                   let participants = data["participants"] as? [String],
                   let currentUserId = self.currentUserId,
                   participants.contains(currentUserId) {
                    completion(true)
                } else {
                    // Пользователь не в списке участников
                    print("User is not a participant of this chat")
                    completion(false)
                }
            } else {
                // Чат не существует
                print("Chat does not exist")
                completion(false)
            }
        }
    }

    // Обновляем метод для использования серверного времени
    private func updateLastMessageWithServerTime(text: String, in chatRoomId: String, messageId: String) {
        let chatRef = db.collection("chatRooms").document(chatRoomId)

        let updateData: [String: Any] = [
            "lastMessage": text,
            "lastMessageDate": FieldValue.serverTimestamp(),
            "lastMessageId": messageId,
            "lastMessageSender": currentUserId ?? ""
        ]

        chatRef.updateData(updateData) { error in
            if let error = error {
                print("Error updating last message: \(error.localizedDescription)")
            } else {
                print("Last message updated successfully")
            }
        }
    }

    func resendMessage(_ message: ChatMessage, in chatRoomId: String) {
        guard message.status == .failed else { return }

        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(message.id)

        var updatedMessage = message
        updatedMessage.status = .sending

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = updatedMessage
        }

        let messageData: [String: Any] = [
            "senderId": message.senderId,
            "senderName": message.senderName,
            "text": message.text,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "status": MessageStatus.sending.rawValue
        ]

        messageRef.setData(messageData) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error resending message: \(error.localizedDescription)")

                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index].status = .failed
                }
            } else {
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index].status = .sent
                }

                self.updateLastMessage(text: message.text, in: chatRoomId)
            }
        }
    }

    func editMessage(messageId: String, in chatRoomId: String, newText: String) {
        guard let currentUserId = currentUserId,
              !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        // Обновляем сообщение локально
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].text = newText
            messages[index].status = .edited
        }

        messageRef.updateData([
            "text": newText,
            "status": MessageStatus.edited.rawValue,
            "editedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error editing message: \(error.localizedDescription)")
                // Восстанавливаем оригинальное сообщение при ошибке
                self.fetchMessages(for: chatRoomId)
            } else {
                // Обновляем последнее сообщение в чате если оно было отредактировано
                messageRef.getDocument { (document, _) in
                    if let document = document, document.exists,
                       let data = document.data(),
                       let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {

                        // Получаем последнее сообщение чата для сравнения
                        let chatRef = self.db.collection("chatRooms").document(chatRoomId)
                        chatRef.getDocument { (chatDoc, _) in
                            if let chatDoc = chatDoc, chatDoc.exists,
                               let chatData = chatDoc.data(),
                               let lastMessageDate = (chatData["lastMessageDate"] as? Timestamp)?.dateValue() {

                                // Если это последнее сообщение, обновляем его в информации о чате
                                if abs(timestamp.timeIntervalSince(lastMessageDate)) < 1 {
                                    self.updateLastMessage(text: newText, in: chatRoomId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateLastMessage(text: String, in chatRoomId: String) {
        let chatRef = db.collection("chatRooms").document(chatRoomId)

        chatRef.updateData([
            "lastMessage": text,
            "lastMessageDate": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating last message: \(error.localizedDescription)")
            }
        }
    }

    func deleteMessage(messageId: String, in chatRoomId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        messageRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error deleting message: \(error.localizedDescription)")
            } else {
                self.messages.remove(at: index)
            }
        }
    }

    func stopListening() {
        messagesListener?.remove()
        chatRoomsListener?.remove()
    }

    deinit {
        stopListening()
    }

    func fetchChatRooms() {
        guard let userId = currentUserId else { return }

        chatRoomsListener?.remove()

        chatRoomsListener = db.collection("chatRooms")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageDate", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error getting chats: \(error.localizedDescription)")
                    return
                }

                self.chatRooms = querySnapshot?.documents.compactMap {
                    ChatRoom(document: $0)
                } ?? []
            }
    }

    func getUnreadMessagesCount(in chatRoomId: String, completion: @escaping (Int) -> Void) {
        guard let currentUserId = currentUserId else {
            completion(0)
            return
        }

        db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .whereField("isRead", isEqualTo: false)
            .whereField("senderId", isNotEqualTo: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting unread messages: \(error.localizedDescription)")
                    completion(0)
                    return
                }

                completion(snapshot?.documents.count ?? 0)
            }
    }

    func deleteChat(chatId: String, completion: @escaping (Bool) -> Void) {
        let chatRef = db.collection("chatRooms").document(chatId)

        // Сначала удаляем все сообщения чата
        chatRef.collection("messages").getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                print("Error fetching messages to delete: \(error.localizedDescription)")
                completion(false)
                return
            }

            let batch = self.db.batch()

            // Добавляем все сообщения к удалению в batch
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }

            // Удаляем сам чат после удаления всех сообщений
            batch.deleteDocument(chatRef)

            // Выполняем batch-операцию
            batch.commit { error in
                if let error = error {
                    print("Error deleting chat: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    // Упрощенная версия обновления информации о чате
    private func updateChatLastMessage(chatRoomId: String, text: String, messageId: String) {
        let chatRef = db.collection("chatRooms").document(chatRoomId)

        print("🔄 Updating chat lastMessage info for chat: \(chatRoomId)")

        chatRef.updateData([
            "lastMessage": text,
            "lastMessageDate": FieldValue.serverTimestamp(),
            "lastMessageId": messageId,
            "lastMessageSender": currentUserId ?? ""
        ]) { error in
            if let error = error {
                print("❌ Error updating chat info: \(error.localizedDescription)")
            } else {
                print("✅ Chat info updated successfully")
            }
        }
    }
}
