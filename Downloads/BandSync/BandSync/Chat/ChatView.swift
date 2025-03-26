import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    let chatRoom: ChatRoom
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    @State private var showingParticipants = false
    @State private var showEmojiPicker = false
    @State private var scrollToBottom = true

    private var isCurrentUserInChat: Bool {
        guard let currentUserId = chatService.currentUserId else { return false }
        return chatRoom.participants.contains(currentUserId)
    }

    var body: some View {
        VStack {
            // Сообщения
            ScrollViewReader { scrollView in
                ScrollView {
                    if chatService.hasMoreMessages {
                        Button(action: {
                            chatService.loadMoreMessages(for: chatRoom.id)
                        }) {
                            if chatService.isLoading {
                                ProgressView()
                                    .padding()
                            } else {
                                Text("Загрузить предыдущие сообщения")
                                    .foregroundColor(.blue)
                                    .padding()
                            }
                        }
                        .disabled(chatService.isLoading)
                        .padding(.top, 8)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(chatService.messages) { message in
                            MessageBubble(message: message,
                                          isFromCurrentUser: message.senderId == chatService.currentUserId)
                                .id(message.id) // для автоскролла
                                .onTapGesture {
                                    // Повторная отправка при ошибке
                                    if message.status == .failed && message.senderId == chatService.currentUserId {
                                        chatService.resendMessage(message, in: chatRoom.id)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: chatService.messages.count) { _ in
                    // Автоскролл к последнему сообщению только при первой загрузке
                    // или при отправке нового сообщения
                    if scrollToBottom, let lastMessage = chatService.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Форма отправки сообщения
            if isCurrentUserInChat {
                VStack(spacing: 0) {
                    // Сообщение об ошибке, если есть
                    if !chatService.errorMessage.isEmpty {
                        Text(chatService.errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                    
                    HStack {
                        // Кнопка выбора смайликов
                        Button(action: {
                            showEmojiPicker.toggle()
                        }) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .padding(8)
                        }
                        
                        TextField("Сообщение...", text: $messageText)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                                .padding(10)
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Панель эмодзи
                    if showEmojiPicker {
                        EmojiPickerView(onEmojiSelected: { emoji in
                            messageText += emoji
                        })
                        .frame(height: 200)
                        .transition(.move(edge: .bottom))
                    }
                }
            } else {
                Text("Вы не являетесь участником этого чата")
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Toggle(isOn: $scrollToBottom) {
                    Image(systemName: "arrow.down.to.line")
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
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
        scrollToBottom = true // Включаем автоскролл при отправке сообщения
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

                HStack {
                    Text(message.text)
                        .padding(10)
                        .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                    
                    // Индикатор статуса сообщения (только для своих сообщений)
                    if isFromCurrentUser {
                        statusIcon
                            .font(.system(size: 12))
                    }
                }

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
    
    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(.gray)
            case .delivered:
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Создаем компонент для выбора эмодзи
struct EmojiPickerView: View {
    var onEmojiSelected: (String) -> Void
    
    // Наиболее используемые эмодзи для рабочего чата
    private let frequentEmojis = ["👍", "👏", "🙌", "🤝", "👀", "👋", "🙂", "😊", "😁", "😄", "😎", "🤔", "🧐", "⏰", "📝", "✅", "❌", "‼️", "❓", "🔥"]
    
    // Категории эмодзи
    private let emojiCategories: [String: [String]] = [
        "Частые": ["👍", "👏", "🙌", "🤝", "👀", "👋", "🙂", "😊", "😁", "😄", "😎", "🤔", "🧐", "⏰", "📝", "✅", "❌", "‼️", "❓", "🔥"],
        "Смайлики": ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🙂", "😊", "😇", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳"],
        "Жесты": ["👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👋", "🤚", "🖐️", "✋", "🖖", "👏", "🙌", "🤝", "💪", "✊", "🤛", "🤜"],
        "Символы": ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯", "☯️", "☦️"],
        "Объекты": ["⏰", "📱", "💻", "⌨️", "🖥️", "🖨️", "📷", "🔋", "🔌", "💡", "🔦", "📚", "📝", "✏️", "📊", "📈", "📉", "🔑", "🔒", "🔓"]
    ]
    
    @State private var selectedCategory = "Частые"
    
    var body: some View {
        VStack(spacing: 8) {
            // Линия-индикатор, что панель можно скрыть
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 4)
            
            // Категории эмодзи
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(emojiCategories.keys), id: \.self) { category in
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(selectedCategory == category ? .blue : .gray)
                            .onTapGesture {
                                selectedCategory = category
                            }
                    }
                }
                .padding(.horizontal)
            }
            
            // Сетка эмодзи
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 8) {
                ForEach(emojiCategories[selectedCategory] ?? [], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 24))
                        .onTapGesture {
                            onEmojiSelected(emoji)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.bottom))
    }
}
