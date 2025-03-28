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
                // Вот этот код вызывается при нажатии на "Ответить"
                replyingToMessage = message
            },
            onTapReply: { messageId in
                // Этот код вызывается при нажатии на цитируемое сообщение
                // Его пока можно оставить пустым
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
            // Стильный и современный индикатор ответа
            if let replyMessage = replyingToMessage {
                HStack(spacing: 4) {
                    // Вертикальная линия с градиентом
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.7), .blue]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 3)

                    // Улучшенное отображение информации с иконкой ответа
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.7))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(replyMessage.senderName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary.opacity(0.8))
                                .lineLimit(1)

                            Text(replyMessage.text)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)

                    Spacer(minLength: 4)

                    // Стильная кнопка закрытия
                    Button(action: {
                        withAnimation(.spring()) {
                            replyingToMessage = nil
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 20, height: 20)

                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.08))
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                )
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .frame(height: 51)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

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
            // Режим редактирования (оставляем без изменений)
            chatService.editMessage(messageId: editingMessage.id, in: chatRoom.id, newText: trimmedText)
            self.editingMessage = nil
        } else {
            // Отправка нового сообщения

            // Проверяем, отвечаем ли мы на сообщение
            if let replyMessage = replyingToMessage {
                // Создаем данные о сообщении, на которое отвечаем
                let replyData = ReplyData(
                    messageId: replyMessage.id,
                    text: replyMessage.text,
                    senderName: replyMessage.senderName,
                    senderId: replyMessage.senderId
                )

                // Отправляем сообщение с ответом
                chatService.sendMessage(text: trimmedText, in: chatRoom.id, replyTo: replyData)

                // Сбрасываем состояние ответа
                replyingToMessage = nil
            } else {
                // Обычная отправка без ответа
                chatService.sendMessage(text: trimmedText, in: chatRoom.id)
            }
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
