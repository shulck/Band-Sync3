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

    private var isCurrentUserInChat: Bool {
        guard let currentUserId = chatService.currentUserId else { return false }
        return chatRoom.participants.contains(currentUserId)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(chatService.isLoading)
                        .padding(.top, 12)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(chatService.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == chatService.currentUserId,
                                onEdit: {
                                    if message.senderId == chatService.currentUserId {
                                        editingMessage = message
                                        messageText = message.text
                                    }
                                },
                                onDelete: {
                                    if message.senderId == chatService.currentUserId {
                                        chatService.deleteMessage(messageId: message.id, in: chatRoom.id)
                                    }
                                }
                            )
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
                    .padding(.vertical, 10)
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
                .background(Color(.systemGroupedBackground))
            }

            // Форма отправки сообщения
            if isCurrentUserInChat {
                VStack(spacing: 0) {
                    Divider()

                    // Сообщение об ошибке, если есть
                    if !chatService.errorMessage.isEmpty {
                        Text(chatService.errorMessage)
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(8)
                            .padding(.top, 8)
                    }

                    // Обновляем нашу форму ввода сообщения
                    HStack(spacing: 8) { // Уменьшаем расстояние между элементами
                        // Кнопка выбора смайликов
                        Button(action: {
                            showEmojiPicker.toggle()
                        }) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 20)) // Уменьшаем размер
                                .foregroundColor(showEmojiPicker ? .blue : .gray)
                                .padding(6) // Меньше отступы
                                .background(showEmojiPicker ? Color.blue.opacity(0.1) : Color.clear)
                                .clipShape(Circle())
                        }

                        // Делаем поле ввода максимально компактным
                        ZStack(alignment: .leading) {
                            if messageText.isEmpty {
                                Text(editingMessage != nil ? "Редактировать..." : "Сообщение...")
                                    .foregroundColor(Color(.placeholderText))
                                    .font(.body)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                            }

                            // Упрощаем структуру для более точного контроля
                            AutoGrowingTextField(text: $messageText, maxHeight: 100, minHeight: 30)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(editingMessage != nil ? Color.blue : Color.clear, lineWidth: 1)
                                )

                            // Кнопка очистки при редактировании
                            if editingMessage != nil {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        messageText = ""
                                        editingMessage = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 16))
                                    }
                                    .padding(.trailing, 12)
                                }
                            }
                        }
                        .frame(minHeight: 34) // Делаем минимальную высоту действительно небольшой

                        // Кнопка отправки
                        Button(action: sendMessage) {
                            Image(systemName: editingMessage != nil ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 20)) // Уменьшаем размер
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                                .padding(6) // Меньше отступы
                                .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 10) // Уменьшаем боковые отступы
                    .padding(.vertical, 6) // Уменьшаем вертикальные отступы
                    .background(Color(.systemBackground))

                    // Панель эмодзи
                    if showEmojiPicker {
                        EmojiPickerView(onEmojiSelected: { emoji in
                            messageText += emoji
                        })
                        .frame(height: 220)
                        .transition(.move(edge: .bottom))
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())

                    Text("Вы не являетесь участником этого чата")
                        .foregroundColor(.gray)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(chatRoom.name)
        .toolbar {
            if chatRoom.isGroupChat {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingParticipants = true }) {
                        Image(systemName: "person.3")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Toggle(isOn: $scrollToBottom) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 16, weight: .medium))
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

        if let editingMessage = editingMessage {
            // Режим редактирования
            chatService.editMessage(
                messageId: editingMessage.id,
                in: chatRoom.id,
                newText: trimmedText
            )
            self.editingMessage = nil
        } else {
            // Отправка нового сообщения
            chatService.sendMessage(text: trimmedText, in: chatRoom.id)
        }

        messageText = ""
        scrollToBottom = true // Включаем автоскролл при отправке сообщения
    }
}

// Обновленная структура MessageBubble
struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer()
            } else {
                // Аватар для сообщений других пользователей
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.senderName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    if message.status == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                    }

                    Text(message.text)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            isFromCurrentUser ?
                                Color.blue :
                                Color(.systemGray5)
                        )
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(18)
                        .contextMenu {
                            // Контекстное меню только для сообщений текущего пользователя
                            if isFromCurrentUser {
                                Button(action: onEdit ?? {}) {
                                    Label("Изменить", systemImage: "pencil")
                                }
                                Button(action: onDelete ?? {}) {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }

                    // Индикатор статуса сообщения (только для своих сообщений)
                    if isFromCurrentUser {
                        statusIcon
                            .font(.system(size: 12))
                    }
                }

                HStack(spacing: 4) {
                    if message.status == .edited {
                        Text("изменено")
                            .font(.system(size: 10))
                            .italic()
                            .foregroundColor(.gray)
                    }

                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 2)
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
            case .edited:
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Полностью переписанное автоувеличивающееся текстовое поле
struct AutoGrowingTextField: UIViewRepresentable {
    @Binding var text: String
    var maxHeight: CGFloat
    var minHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator

        // Установка минимальной высоты
        textView.frame = CGRect(x: 0, y: 0, width: 100, height: minHeight)

        // Минимизация отступов
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineFragmentPadding = 0

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Обновляем текст, если он изменился извне
        if uiView.text != text {
            uiView.text = text
        }

        // Измеряем и применяем высоту на основе содержимого
        updateHeight(uiView)
    }

    private func updateHeight(_ textView: UITextView) {
        // Фиксируем текущую ширину для точных расчетов
        let width = textView.frame.width

        // Рассчитываем необходимую высоту для текста
        let newSize = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))

        // Соблюдаем ограничения минимальной и максимальной высоты
        let boundedHeight = min(max(newSize.height, minHeight), maxHeight)

        // Применяем новую высоту, если она изменилась
        if textView.frame.height != boundedHeight {
            // Включаем скроллинг, если достигли максимальной высоты
            textView.isScrollEnabled = boundedHeight >= maxHeight

            // Обновляем высоту напрямую через frame
            textView.frame.size.height = boundedHeight

            // Обновляем любые существующие ограничения высоты
            for constraint in textView.constraints where constraint.firstAttribute == .height {
                constraint.constant = boundedHeight
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoGrowingTextField

        init(_ parent: AutoGrowingTextField) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Обновляем связанный текст
            DispatchQueue.main.async {
                self.parent.text = textView.text

                // Обновляем высоту при изменении текста
                self.parent.updateHeight(textView)
            }
        }
    }
}
