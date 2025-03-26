import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatService: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var hasMoreMessages: Bool = false

    private let db = Firestore.firestore()
    private var chatRoomsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var lastMessage: QueryDocumentSnapshot?
    private let messagesPerPage = 20

    // Текущий пользователь
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    var currentUserName: String {
        return Auth.auth().currentUser?.displayName ?? "Member"
    }

    // Получение списка чатов для текущего пользователя
    func fetchChatRooms() {
        guard let userId = currentUserId else {
            print("⛔️ Failed to get user ID")
            errorMessage = "Не удалось получить ID пользователя"
            return
        }

        isLoading = true
        print("🔄 Loading chats for user: \(userId)")

        chatRoomsListener?.remove()

        chatRoomsListener = db.collection("chatRooms")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    print("⛔️ Error getting chats: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                    return
                }

                print("✅ Received chats: \(querySnapshot?.documents.count ?? 0)")

                self.chatRooms = querySnapshot?.documents.compactMap { document -> ChatRoom? in
                    let chatRoom = ChatRoom(document: document)
                    print("📝 Chat: \(chatRoom?.name ?? "no name")")
                    return chatRoom
                } ?? []

                print("🏁 Total chats loaded: \(self.chatRooms.count)")
            }
    }

    // Получение сообщений для конкретного чата
    func fetchMessages(for chatRoomId: String) {
        isLoading = true
        errorMessage = ""
        messagesListener?.remove()

        messagesListener = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: messagesPerPage)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    print("⛔️ Error getting messages: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка загрузки сообщений: \(error.localizedDescription)"
                    return
                }

                self.hasMoreMessages = (querySnapshot?.documents.count ?? 0) >= self.messagesPerPage

                if let documents = querySnapshot?.documents, !documents.isEmpty {
                    self.lastMessage = documents.last

                    self.messages = documents.compactMap { document in
                        return ChatMessage(document: document)
                    }.sorted { $0.timestamp < $1.timestamp } // Сортируем по времени
                } else {
                    self.messages = []
                }

                // Отмечаем сообщения как прочитанные
                self.markMessagesAsRead(in: chatRoomId)
            }
    }

    // Загрузка дополнительных сообщений (старых)
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
            .limit(to: messagesPerPage)
            .start(afterDocument: lastMessage)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    print("⛔️ Error loading more messages: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка загрузки сообщений: \(error.localizedDescription)"
                    return
                }

                if let documents = snapshot?.documents, !documents.isEmpty {
                    self.lastMessage = documents.last

                    let oldMessages = documents.compactMap { document -> ChatMessage? in
                        return ChatMessage(document: document)
                    }.sorted { $0.timestamp < $1.timestamp }

                    // Добавляем старые сообщения в начало списка
                    self.messages = oldMessages + self.messages

                    // Есть ли ещё сообщения для загрузки
                    self.hasMoreMessages = documents.count >= self.messagesPerPage
                } else {
                    self.hasMoreMessages = false
                }
            }
    }

    // Отправка нового сообщения
    func sendMessage(text: String, in chatRoomId: String) {
        guard let userId = currentUserId, !text.isEmpty else { return }

        // Создаем сообщение со статусом "отправляется"
        let newMessageId = UUID().uuidString
        let message = ChatMessage(
            id: newMessageId,
            senderId: userId,
            senderName: currentUserName,
            text: text,
            status: .sending
        )

        // Добавляем сообщение локально с временным ID
        DispatchQueue.main.async {
            self.messages.append(message)
        }

        // Добавляем сообщение в коллекцию
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(newMessageId)

        messageRef.setData(message.asDict) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error sending message: \(error.localizedDescription)")
                self.errorMessage = "Ошибка отправки сообщения: \(error.localizedDescription)"

                // Обновляем статус сообщения на "ошибка"
                if let index = self.messages.firstIndex(where: { $0.id == newMessageId }) {
                    DispatchQueue.main.async {
                        self.messages[index].status = .failed
                    }
                }
            } else {
                // Обновляем информацию о последнем сообщении в чате
                self.updateLastMessage(text: text, in: chatRoomId)

                // Обновляем статус сообщения на "отправлено"
                if let index = self.messages.firstIndex(where: { $0.id == newMessageId }) {
                    DispatchQueue.main.async {
                        self.messages[index].status = .sent
                    }
                }
            }
        }
    }

    // Повторная отправка сообщения при ошибке
    func resendMessage(_ message: ChatMessage, in chatRoomId: String) {
        guard message.status == .failed else { return }

        // Обновляем статус сообщения на "отправляется"
        if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
            DispatchQueue.main.async {
                self.messages[index].status = .sending
            }
        }

        // Отправляем сообщение снова
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(message.id)

        messageRef.setData(message.asDict) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error resending message: \(error.localizedDescription)")
                self.errorMessage = "Ошибка отправки сообщения: \(error.localizedDescription)"

                // Обновляем статус сообщения на "ошибка"
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    DispatchQueue.main.async {
                        self.messages[index].status = .failed
                    }
                }
            } else {
                // Обновляем информацию о последнем сообщении в чате
                self.updateLastMessage(text: message.text, in: chatRoomId)

                // Обновляем статус сообщения на "отправлено"
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    DispatchQueue.main.async {
                        self.messages[index].status = .sent
                    }
                }
            }
        }
    }

    // Обновление информации о последнем сообщении
    private func updateLastMessage(text: String, in chatRoomId: String) {
        let chatRef = db.collection("chatRooms").document(chatRoomId)

        chatRef.updateData([
            "lastMessage": text,
            "lastMessageDate": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("⛔️ Error updating last message: \(error.localizedDescription)")
            }
        }
    }

    // Создание нового чата
    func createChat(name: String, participants: [String], isGroupChat: Bool = false) {
        guard let userId = currentUserId else {
            print("⛔️ Failed to get user ID for chat creation")
            errorMessage = "Не удалось получить ID пользователя"
            return
        }

        isLoading = true

        // Убеждаемся, что текущий пользователь включен в участников
        var allParticipants = participants
        if !allParticipants.contains(userId) {
            allParticipants.append(userId)
        }

        print("🔄 Creating chat: \(name) with \(allParticipants.count) participants")

        let chatRoom = ChatRoom(
            name: name,
            participants: allParticipants,
            lastMessageDate: Date(),
            isGroupChat: isGroupChat
        )

        let newChatRef = db.collection("chatRooms").document()

        newChatRef.setData(chatRoom.asDict) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                print("⛔️ Error creating chat: \(error.localizedDescription)")
                self.errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
            } else {
                print("✅ Chat successfully created, ID: \(newChatRef.documentID)")

                // Обновляем список чатов
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchChatRooms()
                }
            }
        }
    }

    // Редактирование сообщения
    func editMessage(messageId: String, in chatRoomId: String, newText: String) {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось получить ID пользователя"
            return
        }

        // Находим сообщение в локальном массиве
        guard let index = messages.firstIndex(where: { $0.id == messageId && $0.senderId == userId }) else {
            errorMessage = "Сообщение не найдено или вы не имеете прав на его редактирование"
            return
        }

        // Обновляем сообщение в Firebase
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        messageRef.updateData([
            "text": newText,
            "status": MessageStatus.edited.rawValue
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error editing message: \(error.localizedDescription)")
                self.errorMessage = "Ошибка редактирования сообщения: \(error.localizedDescription)"
            } else {
                // Обновляем локальное сообщение
                DispatchQueue.main.async {
                    self.messages[index].text = newText
                    self.messages[index].status = .edited
                }

                // Обновляем последнее сообщение в чате, если это последнее сообщение
                if index == self.messages.count - 1 {
                    self.updateLastMessage(text: newText, in: chatRoomId)
                }
            }
        }
    }

    // Удаление сообщения
    func deleteMessage(messageId: String, in chatRoomId: String) {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось получить ID пользователя"
            return
        }

        // Находим сообщение в локальном массиве
        guard let index = messages.firstIndex(where: { $0.id == messageId && $0.senderId == userId }) else {
            errorMessage = "Сообщение не найдено или вы не имеете прав на его удаление"
            return
        }

        // Проверяем, является ли сообщение последним перед удалением
        let isLastMessage = index == messages.count - 1

        // Удаляем сообщение из Firebase
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        messageRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error deleting message: \(error.localizedDescription)")
                self.errorMessage = "Ошибка удаления сообщения: \(error.localizedDescription)"
            } else {
                // Удаляем локальное сообщение
                DispatchQueue.main.async {
                    self.messages.remove(at: index)

                    // Обновляем последнее сообщение в чате, если удалили последнее
                    if isLastMessage {
                        self.updateLastMessageAfterDeletion(in: chatRoomId)
                    }
                }
            }
        }
    }

    // Вспомогательный метод для обновления последнего сообщения после удаления
    private func updateLastMessageAfterDeletion(in chatRoomId: String) {
        // Проверяем, есть ли еще сообщения локально
        if let lastMessage = messages.last {
            // Если есть другие сообщения, используем последнее
            updateLastMessage(text: lastMessage.text, in: chatRoomId)
            return
        }

        // Если локальных сообщений нет, проверяем на сервере
        db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("⛔️ Ошибка поиска последнего сообщения: \(error.localizedDescription)")
                    return
                }

                if let document = snapshot?.documents.first,
                   let lastMessage = ChatMessage(document: document) {
                    // Обновляем информацию о последнем сообщении
                    let chatRef = self.db.collection("chatRooms").document(chatRoomId)
                    chatRef.updateData([
                        "lastMessage": lastMessage.text,
                        "lastMessageDate": Timestamp(date: lastMessage.timestamp)
                    ])
                } else {
                    // Если сообщений больше нет, очищаем информацию о последнем сообщении
                    let chatRef = self.db.collection("chatRooms").document(chatRoomId)
                    chatRef.updateData([
                        "lastMessage": FieldValue.delete(),
                        "lastMessageDate": FieldValue.delete()
                    ])
                }
            }
    }

    // Получение количества непрочитанных сообщений
    func getUnreadMessagesCount(in chatRoomId: String, completion: @escaping (Int) -> Void) {
        guard let userId = currentUserId else {
            completion(0)
            return
        }

        db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .whereField("senderId", isNotEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("⛔️ Error getting unread messages: \(error.localizedDescription)")
                    completion(0)
                    return
                }

                completion(snapshot?.documents.count ?? 0)
            }
    }

    // Отметка сообщений как прочитанных
    private func markMessagesAsRead(in chatRoomId: String) {
        guard let userId = currentUserId else { return }

        // Находим непрочитанные сообщения от других пользователей
        let unreadMessages = messages.filter {
            $0.senderId != userId && !$0.isRead
        }

        for message in unreadMessages {
            db.collection("chatRooms")
                .document(chatRoomId)
                .collection("messages")
                .document(message.id)
                .updateData(["isRead": true])
        }
    }

    // Отмена подписок при выходе из чата
    func stopListening() {
        chatRoomsListener?.remove()
        messagesListener?.remove()
    }

    // Удаление чата
    func deleteChat(chatId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось получить ID пользователя"
            completion(false)
            return
        }

        isLoading = true

        // Проверяем, есть ли у пользователя доступ к этому чату
        db.collection("chatRooms").document(chatId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.isLoading = false
                self.errorMessage = "Ошибка доступа к чату: \(error.localizedDescription)"
                completion(false)
                return
            }

            guard let data = snapshot?.data(),
                  let participants = data["participants"] as? [String],
                  participants.contains(userId) else {
                self.isLoading = false
                self.errorMessage = "У вас нет прав на удаление этого чата"
                completion(false)
                return
            }

            // Сначала удаляем все сообщения в чате
            let messagesRef = self.db.collection("chatRooms").document(chatId).collection("messages")

            messagesRef.getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Ошибка удаления сообщений чата: \(error.localizedDescription)"
                    completion(false)
                    return
                }

                // Если в чате нет сообщений, удаляем сам чат
                if snapshot?.documents.isEmpty ?? true {
                    self.deleteChatDocument(chatId: chatId, completion: completion)
                    return
                }

                // Создаем группу для отслеживания завершения удаления всех сообщений
                let group = DispatchGroup()
                var hasError = false

                // Удаляем каждое сообщение
                for document in snapshot?.documents ?? [] {
                    group.enter()
                    messagesRef.document(document.documentID).delete { error in
                        if let error = error {
                            print("⛔️ Ошибка удаления сообщения: \(error.localizedDescription)")
                            hasError = true
                        }
                        group.leave()
                    }
                }

                // После удаления всех сообщений удаляем сам чат
                group.notify(queue: .main) {
                    if hasError {
                        self.isLoading = false
                        self.errorMessage = "Возникли ошибки при удалении сообщений"
                        completion(false)
                    } else {
                        self.deleteChatDocument(chatId: chatId, completion: completion)
                    }
                }
            }
        }
    }

    // Вспомогательный метод для удаления документа чата
    private func deleteChatDocument(chatId: String, completion: @escaping (Bool) -> Void) {
        db.collection("chatRooms").document(chatId).delete { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                self.errorMessage = "Ошибка удаления чата: \(error.localizedDescription)"
                print("⛔️ Ошибка удаления чата: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Чат успешно удален")
                completion(true)
            }
        }
    }

    // Редактирование чата
    func editChat(chatId: String, newName: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось получить ID пользователя"
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }

        isLoading = true

        // Проверяем, есть ли у пользователя доступ к этому чату
        db.collection("chatRooms").document(chatId).getDocument { [weak self] snapshot, error in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            if let error = error {
                self.isLoading = false
                self.errorMessage = "Ошибка доступа к чату: \(error.localizedDescription)"
                print("⛔️ Ошибка доступа к чату: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            guard let data = snapshot?.data(),
                  let participants = data["participants"] as? [String],
                  participants.contains(userId),
                  let isGroupChat = data["isGroupChat"] as? Bool else {
                self.isLoading = false
                self.errorMessage = "У вас нет прав на редактирование этого чата"
                print("⛔️ У пользователя нет прав редактировать чат")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            // Можно редактировать только групповые чаты
            if !isGroupChat {
                self.isLoading = false
                self.errorMessage = "Нельзя изменить название личного чата"
                print("⛔️ Попытка редактирования личного чата")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            // Обновляем название чата
            let chatRef = self.db.collection("chatRooms").document(chatId)

            chatRef.updateData([
                "name": newName
            ]) { [weak self] error in
                guard let self = self else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Ошибка обновления чата: \(error.localizedDescription)"
                    print("⛔️ Ошибка обновления чата: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                } else {
                    print("✅ Чат успешно обновлен")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                }
            }
        }
    }
}
