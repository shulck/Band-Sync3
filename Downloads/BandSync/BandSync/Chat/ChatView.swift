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
    // Важно: перемещаем переменную высоты поля сюда - на уровень структуры
    @State private var textFieldHeight: CGFloat = 32

    private var isCurrentUserInChat: Bool {
        guard let currentUserId = chatService.currentUserId else { return false }
        return chatRoom.participants.contains(currentUserId)
    }

    var body: some View {
            VStack(spacing: 0) {
                messagesScrollView
                
                if isCurrentUserInChat {
                    messageInputArea
                } else {
                    nonParticipantMessage
                }
            }
            .navigationTitle(chatRoom.name)
            .toolbar {
                toolbarItems
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
        
        // Отдельные компоненты представления
        private var messagesScrollView: some View {
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(spacing: 0) {
                        loadPreviousMessagesButton
                        
                        messagesContent
                    }
                }
                .onChange(of: chatService.messages.count) { _ in
                    scrollToNewMessageIfNeeded(scrollView: scrollView)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        
        private var loadPreviousMessagesButton: some View {
            Group {
                if chatService.hasMoreMessages {
                    Button(action: {
                        chatService.loadMoreMessages(for: chatRoom.id)
                    }) {
                        if chatService.isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            Text("Load Previous Messages")
                                .foregroundColor(.blue)
                                .padding()
                        }
                    }
                    .disabled(chatService.isLoading)
                }
            }
        }
        
    private var messagesContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(chatService.messages) { message in
                messageBubbleView(for: message)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func messageBubbleView(for message: ChatMessage) -> some View {
        MessageBubble(
            message: message,
            isFromCurrentUser: message.senderId == chatService.currentUserId,
            onEdit: {
                handleEditMessage(message)
            },
            onDelete: {
                handleDeleteMessage(message)
            },
            onReply: {
                // Добавьте обработчик для ответа если необходимо
            },
            onTapReply: { messageId in
                // Обработчик нажатия на сообщение с ответом
            }
        )
        .id(message.id)
        .onTapGesture {
            handleMessageTap(message)
        }
    }

    private func handleEditMessage(_ message: ChatMessage) {
        if message.senderId == chatService.currentUserId {
            editingMessage = message
            messageText = message.text
        }
    }

    private func handleDeleteMessage(_ message: ChatMessage) {
        if message.senderId == chatService.currentUserId {
            deleteMessage(message)
        }
    }

    private func handleMessageTap(_ message: ChatMessage) {
        // Повторная отправка при ошибке
        if message.status == .failed && message.senderId == chatService.currentUserId {
            resendMessage(message)
        }
    }
        private var messageInputArea: some View {
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 8) {
                    emojiButton
                    messageTextField
                    sendButton
                }
                .padding(6)
                
                emojiPickerView
            }
            .background(Color(.systemBackground))
        }
        
        private var emojiButton: some View {
            Button(action: {
                showEmojiPicker.toggle()
                // Скрыть клавиатуру при открытии эмодзи
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }) {
                Image(systemName: "face.smiling")
                    .foregroundColor(showEmojiPicker ? .blue : .gray)
            }
            .padding(.leading, 4)
        }
        
        private var messageTextField: some View {
            AutoGrowingTextField(
                text: $messageText,
                minHeight: 32,
                maxHeight: 120,
                height: $textFieldHeight
            )
            .frame(height: textFieldHeight)
            .background(
                editingMessage != nil ? Color.blue.opacity(0.1) : Color(.systemGray6)
            )
            .cornerRadius(18)
            .animation(.easeOut(duration: 0.1), value: textFieldHeight)
        }
        
        private var sendButton: some View {
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
        
        private var emojiPickerView: some View {
            Group {
                if showEmojiPicker {
                    EmojiPickerView(onEmojiSelected: { emoji in
                        messageText += emoji
                    })
                    .frame(height: 250)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        
        private var nonParticipantMessage: some View {
            VStack {
                Text("You are not a participant of this chat")
                    .foregroundColor(.gray)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        
        private var toolbarItems: some ToolbarContent {
            Group {
                if chatRoom.isGroupChat {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingParticipants = true }) {
                            Image(systemName: "person.3")
                        }
                    }
                }
            }
        }
        
        // Вспомогательные методы
        private func scrollToNewMessageIfNeeded(scrollView: ScrollViewProxy) {
            if scrollToBottom, let lastMessage = chatService.messages.last {
                withAnimation {
                    scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
        
        private func resendMessage(_ message: ChatMessage) {
            guard message.status == .failed else { return }
            chatService.resendMessage(message, in: chatRoom.id)
        }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if let editingMessage = editingMessage {
            // Режим редактирования
            chatService.editMessage(messageId: editingMessage.id, in: chatRoom.id, newText: trimmedText)
            self.editingMessage = nil
        } else {
            // Отправка нового сообщения
            chatService.sendMessage(text: trimmedText, in: chatRoom.id)
        }

        messageText = ""
        scrollToBottom = true
    }

    private func deleteMessage(_ message: ChatMessage) {
        // Проверяем, что сообщение отправлено текущим пользователем
        guard message.senderId == chatService.currentUserId else {
            return
        }
        
        // Создаем Alert для подтверждения удаления
        let alert = UIAlertController(
            title: "Удалить сообщение?",
            message: "Это действие нельзя отменить",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            // Вызываем удаление только после подтверждения
            DispatchQueue.main.async {
                self.chatService.deleteMessage(messageId: message.id, in: self.chatRoom.id)
            }
        })
        
        // Показываем Alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var currentController = rootViewController
            while let presentedController = currentController.presentedViewController {
                currentController = presentedController
            }
            currentController.present(alert, animated: true)
        }
    }
    }
