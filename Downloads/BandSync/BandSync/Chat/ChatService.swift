import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatService: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var hasMoreMessages: Bool = false
    @Published var currentChatId: String?

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
        return Auth.auth().currentUser?.displayName ?? "Пользователь"
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
                    print("📝 Chat: \(chatRoom?.name ?? "no name") with \(chatRoom?.participants.count ?? 0) participants")
                    return chatRoom
                } ?? []

                print("🏁 Total chats loaded: \(self.chatRooms.count)")
            }
    }

    // Получение сообщений для конкретного чата
    // Replace fetchMessages method with this improved version
    func fetchMessages(for chatRoomId: String) {
        self.currentChatId = chatRoomId
        guard let userId = currentUserId else {
            self.errorMessage = "Не удалось получить ID пользователя"
            return
        }

        // Проверяем, входит ли пользователь в чат
        db.collection("chatRooms").document(chatRoomId).getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error checking chat access: \(error.localizedDescription)")
                self.errorMessage = "Ошибка доступа к чату: \(error.localizedDescription)"
                return
            }

            guard let document = document,
                  let data = document.data(),
                  let participants = data["participants"] as? [String],
                  participants.contains(userId) else {
                self.errorMessage = "У вас нет доступа к этому чату"
                return
            }

            // Продолжаем загрузку сообщений, так как у пользователя есть доступ
            self.isLoading = true
            self.errorMessage = ""
            self.messages = [] // Очистка предыдущих сообщений
            self.messagesListener?.remove() // Удаляем предыдущий listener

            self.messagesListener = self.db.collection("chatRooms")
                .document(chatRoomId)
                .collection("messages")
                .order(by: "timestamp", descending: false) // Получаем сообщения в хронологическом порядке
                .limit(to: self.messagesPerPage)
                .addSnapshotListener { [weak self] querySnapshot, error in
                    guard let self = self else { return }
                    self.isLoading = false

                    if let error = error {
                        print("⛔️ Error getting messages: \(error.localizedDescription)")
                        self.errorMessage = "Ошибка загрузки сообщений: \(error.localizedDescription)"
                        return
                    }

                    guard let documents = querySnapshot?.documents else {
                        print("No documents in snapshot")
                        self.messages = []
                        self.hasMoreMessages = false
                        return
                    }

                    self.hasMoreMessages = documents.count >= self.messagesPerPage

                    if !documents.isEmpty {
                        self.lastMessage = documents.last

                        // Логирование для отладки
                        print("📩 Received \(documents.count) messages for chat \(chatRoomId)")

                        let newMessages = documents.compactMap { document -> ChatMessage? in
                            let message = ChatMessage(document: document)
                            print("📄 Message from \(message?.senderName ?? "unknown"): \(message?.text ?? "empty")")
                            return message
                        }

                        // Обновляем сообщения напрямую (они уже в правильном порядке)
                        DispatchQueue.main.async {
                            self.messages = newMessages
                        }
                    } else {
                        print("📩 No messages found for chat \(chatRoomId)")
                        self.messages = []
                        self.hasMoreMessages = false
                    }

                    // Отмечаем сообщения как прочитанные
                    self.markMessagesAsRead(in: chatRoomId)
                }
        }
    }

    // Загрузка дополнительных сообщений (старых)
    func loadMoreMessages(for chatRoomId: String) {
        guard let lastMessage = self.lastMessage, !isLoading else {
            self.hasMoreMessages = false
            return
        }

        isLoading = true

        db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: true) // Меняем порядок на обратный для загрузки старых сообщений
            .limit(to: messagesPerPage)
            .start(afterDocument: lastMessage) // Используем start(afterDocument:) вместо endBefore
            .getDocuments { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    print("⛔️ Error loading more messages: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка загрузки сообщений: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.hasMoreMessages = false
                    return
                }

                // Обновляем указатель на самое старое сообщение
                self.lastMessage = documents.last // Используем последний документ в выборке

                let oldMessages = documents.compactMap { document -> ChatMessage? in
                    return ChatMessage(document: document)
                }

                // Добавляем старые сообщения в начало списка (с учетом обратного порядка)
                DispatchQueue.main.async {
                    // Сначала переворачиваем массив, чтобы сохранить хронологию
                    let chronologicalMessages = oldMessages.reversed()
                    self.messages = Array(chronologicalMessages) + self.messages
                }

                // Есть ли ещё сообщения для загрузки
                self.hasMoreMessages = documents.count >= self.messagesPerPage
            }
    }

    // Отправка нового сообщения с поддержкой ответов
    func sendMessage(text: String, in chatRoomId: String, replyTo: ReplyData? = nil) {
        guard let userId = currentUserId, !text.isEmpty else { return }

        // Проверка наличия пользователя в чате
        db.collection("chatRooms").document(chatRoomId).getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error checking chat access: \(error.localizedDescription)")
                self.errorMessage = "Ошибка доступа к чату: \(error.localizedDescription)"
                return
            }

            guard let document = document,
                  let data = document.data(),
                  let participants = data["participants"] as? [String],
                  participants.contains(userId) else {
                self.errorMessage = "Вы не можете отправить сообщение в этот чат"
                return
            }

            // Создаем сообщение со статусом "отправляется"
            let newMessageId = UUID().uuidString
            let message = ChatMessage(
                id: newMessageId,
                senderId: userId,
                senderName: self.currentUserName,
                text: text,
                timestamp: Date(),
                isRead: false,
                status: .sending,
                replyTo: replyTo
            )

            // Добавляем сообщение локально с временным ID
            DispatchQueue.main.async {
                self.messages.append(message)
            }

            // Добавляем сообщение в коллекцию
            let messageRef = self.db.collection("chatRooms")
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
                    print("✅ Message sent successfully: \(newMessageId)")

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
    }

    // Повторная отправка сообщения при ошибке с поддержкой ответов
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

        let currentTime = Date()
        chatRef.updateData([
            "lastMessage": text,
            "lastMessageDate": Timestamp(date: currentTime)
        ]) { error in
            if let error = error {
                print("⛔️ Error updating last message: \(error.localizedDescription)")
            } else {
                print("✅ Last message updated in chat: \(chatRoomId)")
            }
        }
    }

    // Редактирование сообщения с сохранением данных об ответе
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

        // Сохраняем данные об ответе, если они есть
        let replyData = messages[index].replyTo

        // Обновляем сообщение в Firebase
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        var updateData: [String: Any] = [
            "text": newText,
            "status": MessageStatus.edited.rawValue
        ]

        // Добавляем данные об ответе, если они есть
        if let replyData = replyData {
            updateData["replyTo"] = replyData.asDict
        }

        messageRef.updateData(updateData) { [weak self] error in
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
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            errorMessage = "Сообщение не найдено"
            return
        }
        
        // Проверяем, имеет ли пользователь право удалять это сообщение
        let message = messages[index]
        guard message.senderId == userId else {
            errorMessage = "У вас нет прав на удаление этого сообщения"
            return
        }

        // Проверяем, является ли сообщение последним перед удалением
        let isLastMessage = index == messages.count - 1
        
        // Сначала создаем локальную копию сообщения перед удалением из массива
        let messageToDelete = messages[index]
        
        // Удаляем сообщение из Firebase
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        // Сначала удаляем сообщение из локального массива для мгновенного отклика UI
        DispatchQueue.main.async {
            self.messages.remove(at: index)
        }

        messageRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("⛔️ Error deleting message: \(error.localizedDescription)")
                self.errorMessage = "Ошибка удаления сообщения: \(error.localizedDescription)"
                
                // Возвращаем сообщение обратно в массив, если произошла ошибка
                DispatchQueue.main.async {
                    if index < self.messages.count {
                        self.messages.insert(messageToDelete, at: index)
                    } else {
                        self.messages.append(messageToDelete)
                    }
                }
            } else {
                print("✅ Сообщение успешно удалено: \(messageId)")

                // Обновляем последнее сообщение в чате, если удалили последнее
                if isLastMessage {
                    self.updateLastMessageAfterDeletion(in: chatRoomId)
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

                let count = snapshot?.documents.count ?? 0
                print("📊 Unread messages in chat \(chatRoomId): \(count)")
                completion(count)
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
            print("📖 Marking message as read: \(message.id)")

            db.collection("chatRooms")
                .document(chatRoomId)
                .collection("messages")
                .document(message.id)
                .updateData(["isRead": true]) { error in
                    if let error = error {
                        print("⛔️ Error marking message as read: \(error.localizedDescription)")
                    } else {
                        print("✅ Message marked as read: \(message.id)")
                    }
                }
        }
    }

    // Отмена подписок при выходе из чата
    func stopListening() {
        print("🛑 Stopping chat listeners")
        chatRoomsListener?.remove()
        messagesListener?.remove()
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
        if (!allParticipants.contains(userId)) {
            allParticipants.append(userId)
        }

        print("🔄 Creating chat: \(name) with \(allParticipants.count) participants")

        let chatId = UUID().uuidString
        let chatRoom = ChatRoom(
            id: chatId,
            name: name,
            participants: allParticipants,
            lastMessageDate: Date(),
            isGroupChat: isGroupChat
        )

        let newChatRef = db.collection("chatRooms").document(chatId)

        newChatRef.setData(chatRoom.asDict) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                print("⛔️ Error creating chat: \(error.localizedDescription)")
                self.errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
            } else {
                print("✅ Chat successfully created, ID: \(chatId)")

                // Добавляем системное сообщение
                let welcomeMessage = "Чат создан"
                self.addSystemMessage(chatId: chatId, text: welcomeMessage)

                // Обновляем список чатов
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchChatRooms()
                }
            }
        }
    }

    // Добавление системного сообщения
    private func addSystemMessage(chatId: String, text: String) {
        let systemMessageId = UUID().uuidString
        let systemMessage: [String: Any] = [
            "senderId": "system",
            "senderName": "System",
            "text": text,
            "timestamp": Timestamp(date: Date()),
            "isRead": true,
            "status": MessageStatus.sent.rawValue
        ]

        db.collection("chatRooms")
            .document(chatId)
            .collection("messages")
            .document(systemMessageId)
            .setData(systemMessage) { error in
                if let error = error {
                    print("⛔️ Error adding system message: \(error.localizedDescription)")
                } else {
                    print("✅ System message added to chat: \(chatId)")
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
            if (!isGroupChat) {
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

                    // Добавляем системное сообщение о переименовании
                    self.addSystemMessage(chatId: chatId, text: "Чат переименован на '\(newName)'")

                    // Обновляем локальный список
                    if let index = self.chatRooms.firstIndex(where: { $0.id == chatId }) {
                        DispatchQueue.main.async {
                            self.chatRooms[index].name = newName
                            completion(true)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                }
            }
        }
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
                if (snapshot?.documents.isEmpty ?? true) {
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
                    if (hasError) {
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
                // Обновим локальный список
                self.chatRooms.removeAll { $0.id == chatId }
                completion(true)
            }
        }
    }
}
