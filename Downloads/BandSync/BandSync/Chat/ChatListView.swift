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

    var filteredChatRooms: [ChatRoom] {
        if searchText.isEmpty {
            return chatService.chatRooms
        } else {
            return chatService.chatRooms.filter {
                $0.name.lowercased().contains(searchText.lowercased())
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
                        Image(systemName: "message.circle")
                            .font(.system(size: 72))
                            .foregroundColor(.gray)

                        Text("У вас пока нет чатов")
                            .font(.headline)

                        Text("Создайте новый чат, чтобы начать общение")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: {
                            showingNewChatView = true
                        }) {
                            Text("Создать новый чат")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredChatRooms) { chatRoom in
                            NavigationLink(destination: ChatView(chatRoom: chatRoom)) {
                                HStack {
                                    // Аватар чата (иконка группы или индивидуальная)
                                    ZStack {
                                        Image(systemName: chatRoom.isGroupChat ? "person.3.fill" : "person.fill")
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(Circle().fill(Color.blue))

                                        // Индикатор непрочитанных сообщений
                                        if let unreadCount = unreadCounts[chatRoom.id], unreadCount > 0 {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 20, height: 20)

                                                Text("\(unreadCount)")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.bold)
                                            }
                                            .offset(x: 15, y: -15)
                                        }
                                    }

                                    VStack(alignment: .leading) {
                                        Text(chatRoom.name)
                                            .font(.headline)

                                        if let lastMessage = chatRoom.lastMessage {
                                            Text(lastMessage)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if let date = chatRoom.lastMessageDate {
                                        Text(formatDate(date))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
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
            .searchable(text: $searchText, prompt: "Поиск чатов")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewChatView = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewChatView) {
                NewChatView(chatService: chatService)
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
                EditChatView(
                    chatId: chatRoom.id,
                    chatName: $editChatName,
                    onSave: { success in
                        if success {
                            // Обновляем список чатов
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                chatService.fetchChatRooms()
                            }
                        }
                    }
                )
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
