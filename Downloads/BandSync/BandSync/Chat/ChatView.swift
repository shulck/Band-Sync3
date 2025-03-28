import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    let chatRoom: ChatRoom
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    @State private var showingParticipants = false
    @State private var showEmojiPicker = false
    @State private var scrollToBottom = true
    @State private var editingMessage: ChatMessage?
    @State private var replyingToMessage: ChatMessage?
    @State private var textFieldHeight: CGFloat = 32
    @State private var scrollToMessageId: String?

    private var isCurrentUserInChat: Bool {
        guard let currentUserId = chatService.currentUserId else { return false }
        return chatRoom.participants.contains(currentUserId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Основной контент - список сообщений
            MessagesListView(
                chatService: chatService,
                scrollToBottom: $scrollToBottom,
                editingMessage: $editingMessage,
                replyingToMessage: $replyingToMessage,
                messageText: $messageText,
                scrollToMessageId: $scrollToMessageId,
                chatRoomId: chatRoom.id
            )

            // Форма отправки сообщения
            if isCurrentUserInChat {
                MessageInputView(
                    messageText: $messageText,
                    showEmojiPicker: $showEmojiPicker,
                    textFieldHeight: $textFieldHeight,
                    editingMessage: $editingMessage,
                    replyingToMessage: $replyingToMessage,
                    scrollToBottom: $scrollToBottom,
                    chatRoom: chatRoom,
                    chatService: chatService
                )
            } else {
                NonParticipantView()
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
}

// MARK: - Вспомогательные компоненты

// Компонент списка сообщений
struct MessagesListView: View {
    @ObservedObject var chatService: ChatService
    @Binding var scrollToBottom: Bool
    @Binding var editingMessage: ChatMessage?
    @Binding var replyingToMessage: ChatMessage?
    @Binding var messageText: String
    @Binding var scrollToMessageId: String?
    let chatRoomId: String
    
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                // Кнопка загрузки предыдущих сообщений
                if chatService.hasMoreMessages {
                    Button(action: {
                        chatService.loadMoreMessages(for: chatRoomId)
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
                }

                // Список сообщений
                LazyVStack(spacing: 12) {
                    ForEach(chatService.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == chatService.currentUserId,
                            onEdit: {
                                if message.senderId == chatService.currentUserId {
                                    editingMessage = message
                                    replyingToMessage = nil
                                    messageText = message.text
                                }
                            },
                            onDelete: {
                                if message.senderId == chatService.currentUserId {
                                    deleteMessage(message)
                                }
                            },
                            onReply: {
                                replyingToMessage = message
                                editingMessage = nil
                            },
                            onTapReply: { replyMessageId in
                                scrollToMessageId = replyMessageId
                                scrollView.scrollTo(replyMessageId, anchor: .center)
                                
                                // Анимация подсветки
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    scrollToMessageId = nil
                                }
                            }
                        )
                        .id(message.id)
                        .padding(.horizontal)
                        .background(scrollToMessageId == message.id ? Color.yellow.opacity(0.2) : Color.clear)
                        .animation(.easeInOut(duration: 0.3), value: scrollToMessageId == message.id)
                        .onTapGesture {
                            // Повторная отправка при ошибке
                            if message.status == .failed && message.senderId == chatService.currentUserId {
                                resendMessage(message)
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            .onChange(of: chatService.messages.count) { _ in
                if scrollToBottom, let lastMessage = chatService.messages.last {
                    withAnimation {
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func deleteMessage(_ message: ChatMessage) {
        chatService.deleteMessage(messageId: message.id, in: chatRoomId)
    }
    
    private func resendMessage(_ message: ChatMessage) {
        chatService.resendMessage(message, in: chatRoomId)
    }
}

// Компонент формы отправки сообщений
struct MessageInputView: View {
    @Binding var messageText: String
    @Binding var showEmojiPicker: Bool
    @Binding var textFieldHeight: CGFloat
    @Binding var editingMessage: ChatMessage?
    @Binding var replyingToMessage: ChatMessage?
    @Binding var scrollToBottom: Bool
    let chatRoom: ChatRoom
    @ObservedObject var chatService: ChatService
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            // Панель ответа на сообщение
            if let replyingToMessage = replyingToMessage {
                ReplyHeaderView(message: replyingToMessage) {
                    self.replyingToMessage = nil
                }
            }
            
            // Индикатор режима редактирования
            if editingMessage != nil {
                EditingHeaderView {
                    self.editingMessage = nil
                    self.messageText = ""
                }
            }

            // Контейнер ввода сообщения
            HStack(spacing: 8) {
                // Кнопка эмодзи
                Button(action: {
                    showEmojiPicker.toggle()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Image(systemName: "face.smiling")
                        .foregroundColor(showEmojiPicker ? .blue : .gray)
                }
                .padding(.leading, 4)

                // Текстовое поле
                AutoGrowingTextField(
                    text: $messageText,
                    minHeight: 32,
                    maxHeight: 120,
                    height: $textFieldHeight
                )
                .frame(height: textFieldHeight)
                .background(
                    (editingMessage != nil || replyingToMessage != nil) ?
                        Color.blue.opacity(0.1) : Color(.systemGray6)
                )
                .cornerRadius(18)
                .animation(.easeOut(duration: 0.1), value: textFieldHeight)

                // Кнопка отправки
                Button(action: sendMessage) {
                    Image(systemName: editingMessage != nil
                        ? "checkmark.circle.fill"
                        : "paperplane.fill")
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .gray
                            : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(6)

            // Панель эмодзи
            if showEmojiPicker {
                EmojiPickerView(onEmojiSelected: { emoji in
                    messageText += emoji
                })
                .frame(height: 250)
                .transition(.move(edge: .bottom))
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if let editingMessage = editingMessage {
            // Режим редактирования
            chatService.editMessage(messageId: editingMessage.id, in: chatRoom.id, newText: trimmedText)
            self.editingMessage = nil
        } else {
            // Отправка нового сообщения, возможно, с ответом
            if let replyToMessage = replyingToMessage {
                let replyData = ReplyData(
                    messageId: replyToMessage.id,
                    text: replyToMessage.text,
                    senderName: replyToMessage.senderName,
                    senderId: replyToMessage.senderId
                )
                chatService.sendMessage(text: trimmedText, in: chatRoom.id, replyTo: replyData)
            } else {
                // Обычное сообщение без ответа
                chatService.sendMessage(text: trimmedText, in: chatRoom.id)
            }
            self.replyingToMessage = nil
        }

        messageText = ""
        scrollToBottom = true
    }
}

// Заголовок ответа на сообщение
struct ReplyHeaderView: View {
    let message: ChatMessage
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Ответ для")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 8)
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .background(Color(.systemGray6))
    }
}

// Заголовок режима редактирования
struct EditingHeaderView: View {
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundColor(.blue)
            
            Text("Редактирование сообщения")
                .font(.caption)
                .foregroundColor(.blue)
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 8)
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .background(Color(.systemGray6))
    }
}

// Представление для неучастников чата
struct NonParticipantView: View {
    var body: some View {
        VStack {
            Text("Вы не являетесь участником этого чата")
                .foregroundColor(.gray)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
