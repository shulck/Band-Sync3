import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatService: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var hasMoreMessages: Bool = true
    
    private let db = Firestore.firestore()
    private var chatRoomsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var lastMessage: QueryDocumentSnapshot?

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

        print("🔄 Loading chats for user: \(userId)")
        
        isLoading = true
        errorMessage = ""
        chatRoomsListener?.remove()

        chatRoomsListener = db.collection("chatRooms")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    print("⛔️ Error getting chats: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка загрузки чатов: проверьте подключение"
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
        messagesListener?.remove()
        
        // Сбрасываем состояние пагинации при первой загрузке
        hasMoreMessages = true
        lastMessage = nil
        isLoading = true
        errorMessage = ""
        
        // Ограничиваем количество загружаемых сообщений
        let limit = 30
        
        messagesListener = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { [weak self] (querySnapshot: QuerySnapshot?, error: Error?) in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("⛔️ Error getting messages: \(error.localizedDescription)")
                    self.errorMessage = "Не удалось загрузить сообщения. Попробуйте еще раз."
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.messages = []
                    return
                }
                
                let newMessages = documents.compactMap { ChatMessage(document: $0) }
                
                // Сохраняем последнее сообщение для пагинации
                if !documents.isEmpty {
                    self.lastMessage = documents.last
                } else {
                    self.hasMoreMessages = false
                }
                
                // Переворачиваем, чтобы старые были сначала
                self.messages = newMessages.reversed()
                
                // Отмечаем сообщения как прочитанные
                self.markMessagesAsRead(in: chatRoomId)
                
                // Кэшируем сообщения локально
                self.cacheMessages(newMessages, for: chatRoomId)
            }
    }
    
    // Загрузка предыдущих сообщений (более старых)
    func loadMoreMessages(for chatRoomId: String) {
        guard hasMoreMessages, !isLoading, let lastMessage = self.lastMessage else { return }
        
        isLoading = true
        
        let limit = 20
        
        db.collection("chatRooms")
                .document(chatRoomId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .start(afterDocument: lastMessage) // startAfter изменено на start(afterDocument:)
                .getDocuments { [weak self] (snapshot: QuerySnapshot?, error: Error?) in // Добавлены типы параметров
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        print("⛔️ Error loading more messages: \(error.localizedDescription)")
                        self.errorMessage = "Ошибка при загрузке старых сообщений"
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.hasMoreMessages = false
                        return
                    }
                    
                    let oldMessages = documents.compactMap { ChatMessage(document: $0) }
                    
                    // Обновляем последнее сообщение для пагинации
                    self.lastMessage = documents.last
                    
                    // Добавляем старые сообщения к существующим
                    let newMessages = self.messages + oldMessages.reversed()
                    self.messages = newMessages
                    
                    // Кэшируем сообщения локально
                    self.cacheMessages(oldMessages, for: chatRoomId)
                }
        }
    // Отправка нового сообщения
    func sendMessage(text: String, in chatRoomId: String) {
        guard let userId = currentUserId, !text.isEmpty else { return }
        
        // Создаем локальный ID для сообщения
        let messageId = UUID().uuidString
        
        let message = ChatMessage(
            id: messageId,
            senderId: userId,
            senderName: currentUserName,
            text: text,
            timestamp: Date(),
            isRead: false,
            status: .sending
        )
        
        // Добавляем сообщение локально для мгновенного отображения
        DispatchQueue.main.async {
            self.messages.append(message)
        }

        // Добавляем сообщение в коллекцию
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(messageId)

        messageRef.setData(message.asDict) { error in
            if let error = error {
                print("⛔️ Error sending message: \(error.localizedDescription)")
                
                // Обновляем статус сообщения на "failed"
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                        self.messages[index].status = .failed
                    }
                }
            } else {
                // Обновляем информацию о последнем сообщении в чате
                self.updateLastMessage(text: text, in: chatRoomId)
                
                // Обновляем статус сообщения на "sent"
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                        self.messages[index].status = .sent
                    }
                }
            }
        }
    }

    // Повторная отправка сообщения при ошибке
    func resendMessage(_ message: ChatMessage, in chatRoomId: String) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        // Обновляем статус на "sending"
        DispatchQueue.main.async {
            self.messages[index].status = .sending
        }
        
        // Отправляем сообщение
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document(message.id)
        
        messageRef.setData(message.asDict) { error in
            if let error = error {
                print("⛔️ Error resending message: \(error.localizedDescription)")
                
                // Обновляем статус сообщения на "failed"
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                        self.messages[index].status = .failed
                    }
                }
            } else {
                // Обновляем информацию о последнем сообщении в чате
                self.updateLastMessage(text: message.text, in: chatRoomId)
                
                // Обновляем статус сообщения на "sent"
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
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

        // Убеждаемся, что текущий пользователь включен в участников
        var allParticipants = participants
        if !allParticipants.contains(userId) {
            allParticipants.append(userId)
        }

        print("🔄 Creating chat: \(name) with \(allParticipants.count) participants")
        
        isLoading = true
        errorMessage = ""

        let chatRoom = ChatRoom(
            name: name,
            participants: allParticipants,
            lastMessageDate: Date(),
            isGroupChat: isGroupChat
        )

        let newChatRef = db.collection("chatRooms").document()

        newChatRef.setData(chatRoom.asDict) { error in
            self.isLoading = false
            
            if let error = error {
                print("⛔️ Error creating chat: \(error.localizedDescription)")
                self.errorMessage = "Ошибка при создании чата: \(error.localizedDescription)"
            } else {
                print("✅ Chat successfully created, ID: \(newChatRef.documentID)")

                // Обновляем список чатов
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchChatRooms()
                }
            }
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
    
    // Кэширование сообщений
    private func cacheMessages(_ messages: [ChatMessage], for chatRoomId: String) {
        // Здесь должна быть реализация кэширования сообщений
        // Например, сохранение в UserDefaults или Core Data
        
        // Пример для UserDefaults (для небольшого количества сообщений):
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(messages) {
            UserDefaults.standard.set(encoded, forKey: "cached_messages_\(chatRoomId)")
        }
    }
    
    // Загрузка кэшированных сообщений
    func loadCachedMessages(for chatRoomId: String) -> [ChatMessage] {
        // Пример загрузки из UserDefaults:
        if let data = UserDefaults.standard.data(forKey: "cached_messages_\(chatRoomId)") {
            let decoder = JSONDecoder()
            if let messages = try? decoder.decode([ChatMessage].self, from: data) {
                return messages
            }
        }
        return []
    }

    // Отмена подписок при выходе из чата
    func stopListening() {
        chatRoomsListener?.remove()
        messagesListener?.remove()
    }
    
    // Проверка наличия непрочитанных сообщений в чате
    func hasUnreadMessages(in chatRoom: ChatRoom) -> Bool {
        // Загружаем последние сообщения для проверки
        guard let userId = currentUserId else { return false }
        
        // Здесь должен быть запрос к Firestore для проверки непрочитанных сообщений
        // Для примера возвращаем false
        return false
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
            .whereField("isRead", isEqualTo: false)
            .whereField("senderId", isNotEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("⛔️ Error getting unread count: \(error.localizedDescription)")
                    completion(0)
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                completion(count)
            }
    }
}
