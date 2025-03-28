import SwiftUI
import FirebaseAuth

struct ChatListView: View {
    @StateObject private var chatService = ChatService()
    @State private var showingNewChatView = false
    @State private var searchText = ""
    @State private var unreadCounts: [String: Int] = [:]
    @State private var showDeleteAlert = false
    @State private var chatToDelete: ChatRoom?
    @State private var chatToEdit: ChatRoom?
    @State private var editChatName = ""

    // Упрощённая версия фильтрации
    private var filteredRooms: [ChatRoom] {
        if searchText.isEmpty {
            return chatService.chatRooms
        } else {
            return chatService.chatRooms.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if chatService.isLoading && chatService.chatRooms.isEmpty {
                    ProgressView("Загрузка чатов...")
                        .padding()
                } else if chatService.chatRooms.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color.blue.opacity(0.8))
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)

                        Text("У вас пока нет чатов")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Создайте новый чат, чтобы начать общение")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .font(.subheadline)

                        Button(action: {
                            showingNewChatView = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Создать новый чат")
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredRooms) { chatRoom in
                            NavigationLink(destination: ChatView(chatRoom: chatRoom)) {
                                HStack(spacing: 12) {
                                    // Аватар чата с улучшенным дизайном
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 50, height: 50)
                                            .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)

                                        Image(systemName: chatRoom.isGroupChat ? "person.3.fill" : "person.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: chatRoom.isGroupChat ? 20 : 24))

                                        // Индикатор непрочитанных сообщений
                                        if let unreadCount = unreadCounts[chatRoom.id], unreadCount > 0 {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 22, height: 22)
                                                    .shadow(color: Color.red.opacity(0.5), radius: 2, x: 0, y: 1)

                                                Text("\(unreadCount)")
                                                    .font(.caption2.bold())
                                                    .foregroundColor(.white)
                                            }
                                            .offset(x: 18, y: -18)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(chatRoom.name)
                                            .font(.headline)
                                            .fontWeight(.semibold)

                                        if let lastMessage = chatRoom.lastMessage {
                                            Text(lastMessage)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        if let date = chatRoom.lastMessageDate {
                                            Text(formatDate(date))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .contextMenu {
                                if chatRoom.isGroupChat {
                                    Button(action: {
                                        chatToEdit = chatRoom
                                        editChatName = chatRoom.name
                                    }) {
                                        Label("Редактировать", systemImage: "pencil")
                                    }
                                }

                                Button(role: .destructive, action: {
                                    chatToDelete = chatRoom
                                    showDeleteAlert = true
                                }) {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    chatToDelete = chatRoom
                                    showDeleteAlert = true
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }

                                if chatRoom.isGroupChat {
                                    Button {
                                        chatToEdit = chatRoom
                                        editChatName = chatRoom.name
                                    } label: {
                                        Label("Изменить", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        chatService.fetchChatRooms()
                        loadUnreadCounts()
                    }
                }
            }
            .navigationTitle("Чаты")
            .navigationBarItems(trailing: Button(action: {
                showingNewChatView = true
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
            })

            .sheet(isPresented: $showingNewChatView) {
                // Исправленный вызов - создаем новый пустой ChatRoom
                ChatView(chatRoom: ChatRoom(
                    name: "Новый чат",
                    participants: [Auth.auth().currentUser?.uid].compactMap { $0 },
                    isGroupChat: false
                ))
            }
            .alert("Удалить чат?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    if let chatId = chatToDelete?.id {
                        deleteChat(chatId: chatId)
                    }
                }
            } message: {
                Text("Вы уверены, что хотите удалить чат? Это действие невозможно отменить.")
            }
            .sheet(item: $chatToEdit) { chatRoom in
                // Исправленный вызов - используем существующий ChatRoom
                ChatView(chatRoom: chatRoom)
            }
            .onAppear {
                chatService.fetchChatRooms()
                loadUnreadCounts()
            }
            .onDisappear {
                chatService.stopListening()
            }
            .overlay(
                Group {
                    if !chatService.errorMessage.isEmpty {
                        VStack {
                            Text(chatService.errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)

                            Spacer()
                        }
                        .padding(.top)
                    }
                }
            )
        }
    }

    // Форматирование даты для отображения
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: date)
        }
    }

    // Загрузка количества непрочитанных сообщений для всех чатов
    private func loadUnreadCounts() {
        for chatRoom in chatService.chatRooms {
            chatService.getUnreadMessagesCount(in: chatRoom.id) { count in
                DispatchQueue.main.async {
                    unreadCounts[chatRoom.id] = count
                }
            }
        }
    }

    // Удаление чата
    private func deleteChat(chatId: String) {
        chatService.deleteChat(chatId: chatId) { success in
            if success {
                // Обновление происходит автоматически через listener
                chatToDelete = nil
            }
        }
    }
}
