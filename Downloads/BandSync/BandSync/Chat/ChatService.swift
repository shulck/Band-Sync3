import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatService: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var messages: [ChatMessage] = []

    private let db = Firestore.firestore()
    private var chatRoomsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?

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
            return
        }

        print("🔄 Loading chats for user: \(userId)")

        chatRoomsListener?.remove()

        chatRoomsListener = db.collection("chatRooms")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("⛔️ Error getting chats: \(error.localizedDescription)")
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

        messagesListener = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("⛔️ Error getting messages: \(error.localizedDescription)")
                    return
                }

                self.messages = querySnapshot?.documents.compactMap { document in
                    return ChatMessage(document: document)
                } ?? []

                // Отмечаем сообщения как прочитанные
                self.markMessagesAsRead(in: chatRoomId)
            }
    }

    // Отправка нового сообщения
    func sendMessage(text: String, in chatRoomId: String) {
        guard let userId = currentUserId, !text.isEmpty else { return }

        let message = ChatMessage(
            senderId: userId,
            senderName: currentUserName,
            text: text
        )

        // Добавляем сообщение в коллекцию
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document()

        messageRef.setData(message.asDict) { error in
            if let error = error {
                print("⛔️ Error sending message: \(error.localizedDescription)")
            } else {
                // Обновляем информацию о последнем сообщении в чате
                self.updateLastMessage(text: text, in: chatRoomId)
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
            return
        }

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

        newChatRef.setData(chatRoom.asDict) { error in
            if let error = error {
                print("⛔️ Error creating chat: \(error.localizedDescription)")
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

    // Отмена подписок при выходе из чата
    func stopListening() {
        chatRoomsListener?.remove()
        messagesListener?.remove()
    }
}
