import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    let chatRoom: ChatRoom
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    @State private var showingParticipants = false

    private var isCurrentUserInChat: Bool {
        guard let currentUserId = chatService.currentUserId else { return false }
        return chatRoom.participants.contains(currentUserId)
    }

    var body: some View {
        VStack {
            // Сообщения
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatService.messages) { message in
                            MessageBubble(message: message,
                                        isFromCurrentUser: message.senderId == chatService.currentUserId)
                                .id(message.id) // для автоскролла
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: chatService.messages.count) { _ in
                    // Автоскролл к последнему сообщению
                    if let lastMessage = chatService.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Форма отправки сообщения
            if isCurrentUserInChat {
                HStack {
                    TextField("Message...", text: $messageText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                            .padding(10)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                Text("You are not a participant of this chat")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .navigationTitle(chatRoom.name)
        .toolbar {
            if chatRoom.isGroupChat {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingParticipants = true }) {
                        Image(systemName: "person.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showingParticipants) {
            ParticipantsView(participants: chatRoom.participants)
        }
        .onAppear {
            chatService.fetchMessages(for: chatRoom.id)
        }
        .onDisappear {
            chatService.stopListening()
        }
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        chatService.sendMessage(text: trimmedText, in: chatRoom.id)
        messageText = ""
    }
}

// Компонент пузыря сообщения
struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }

                Text(message.text)
                    .padding(10)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Представление списка участников
struct ParticipantsView: View {
    let participants: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var userNames: [String: String] = [:]

    var body: some View {
        NavigationView {
            List {
                ForEach(participants, id: \.self) { participantId in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)

                        Text(userNames[participantId] ?? "Загрузка...")
                    }
                }
            }
            .navigationTitle("Participants")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                loadUserNames()
            }
        }
    }

    private func loadUserNames() {
        let db = Firestore.firestore()

        for participantId in participants {
            db.collection("users").document(participantId).getDocument { snapshot, error in
                if let error = error {
                    print("Error loading user data: \(error.localizedDescription)")
                    return
                }

                // Проверяем разные поля, где может храниться имя
                if let data = snapshot?.data() {
                    // Пробуем найти имя в различных полях
                    if let name = data["name"] as? String, !name.isEmpty {
                        self.userNames[participantId] = name
                    } else if let name = data["displayName"] as? String, !name.isEmpty {
                        self.userNames[participantId] = name
                    } else if let firstName = data["firstName"] as? String,
                              let lastName = data["lastName"] as? String,
                              !firstName.isEmpty {
                        if lastName.isEmpty {
                            self.userNames[participantId] = firstName
                        } else {
                            self.userNames[participantId] = "\(firstName) \(lastName)"
                        }
                    } else if let email = data["email"] as? String {
                        // Если имя не найдено, создаем имя из email
                        let username = email.components(separatedBy: "@").first ?? email
                        let formattedName = username
                            .replacingOccurrences(of: ".", with: " ")
                            .split(separator: " ")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                            .joined(separator: " ")

                        self.userNames[participantId] = formattedName
                    } else {
                        // Если совсем ничего не найдено
                        self.userNames[participantId] = "User \(participantId.prefix(5))"
                    }
                } else {
                    // Если документ не найден
                    self.userNames[participantId] = "User \(participantId.prefix(5))"
                }
            }
        }
    }
}
