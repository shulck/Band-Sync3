import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NewChatView: View {
    @ObservedObject var chatService: ChatService
    var onDismiss: () -> Void

    @State private var chatName = ""
    @State private var isGroupChat = false
    @State private var selectedUsers: [String] = []
    @State private var searchText = ""
    @State private var availableUsers: [UserProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Загрузка пользователей...")
                        .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("Ошибка")
                            .font(.headline)

                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Button("Повторить") {
                            loadUsers()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    Form {
                        Section(header: Text("Тип чата")) {
                            Toggle("Групповой чат", isOn: $isGroupChat)
                                .onChange(of: isGroupChat) { newValue in
                                    if !newValue && selectedUsers.count > 1 {
                                        // Оставляем только первого пользователя для личного чата
                                        selectedUsers = Array(selectedUsers.prefix(1))
                                    }
                                }

                            if isGroupChat {
                                TextField("Название чата", text: $chatName)
                                    .autocapitalization(.words)
                            }
                        }

                        Section(header: Text("Выбрать участников")) {
                            ForEach(filteredUsers, id: \.id) { user in
                                UserRow(
                                    user: user,
                                    isSelected: selectedUsers.contains(user.id),
                                    onToggle: { isSelected in
                                        toggleUser(user: user, isSelected: isSelected)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(isGroupChat ? "Новый групповой чат" : "Новый чат")
            .navigationBarItems(
                leading: Button("Отмена") {
                    onDismiss()
                },
                trailing: Button("Создать") {
                    createChat()
                }
                .disabled(selectedUsers.isEmpty || (isGroupChat && chatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            )
            .onAppear {
                loadUsers()
            }
        }
    }

    // Фильтрация пользователей по поисковому запросу
    private var filteredUsers: [UserProfile] {
        guard !searchText.isEmpty else {
            return availableUsers
        }

        return availableUsers.filter { user in
            user.name.localizedCaseInsensitiveContains(searchText) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Загрузка списка пользователей из Firestore
    private func loadUsers() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            errorMessage = "Не удалось получить ID текущего пользователя"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                errorMessage = "Ошибка загрузки пользователей: \(error.localizedDescription)"
                isLoading = false
                return
            }

            var users: [UserProfile] = []

            for document in snapshot?.documents ?? [] {
                let data = document.data()
                let userId = document.documentID

                // Пропускаем текущего пользователя
                if userId == currentUserId {
                    continue
                }

                let name = data["name"] as? String ?? data["displayName"] as? String ?? "Пользователь"
                let email = data["email"] as? String ?? ""

                let user = UserProfile(id: userId, name: name, email: email)
                users.append(user)
            }

            self.availableUsers = users
            isLoading = false
        }
    }

    // Добавление/удаление пользователя из выбранных
    private func toggleUser(user: UserProfile, isSelected: Bool) {
        if isSelected {
            if !selectedUsers.contains(user.id) {
                if !isGroupChat && selectedUsers.count >= 1 {
                    // Для личного чата можно выбрать только одного пользователя
                    selectedUsers = [user.id]
                } else {
                    selectedUsers.append(user.id)
                }
            }
        } else {
            selectedUsers.removeAll { $0 == user.id }
        }
    }

    // Создание нового чата
    private func createChat() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }

        if selectedUsers.isEmpty {
            return
        }

        // Формируем список всех участников чата
        var participants = selectedUsers
        if !participants.contains(currentUserId) {
            participants.append(currentUserId)
        }

        // Определяем название чата
        var chatName = self.chatName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isGroupChat {
            // Для личного чата используем имя собеседника
            if let userId = selectedUsers.first,
               let user = availableUsers.first(where: { $0.id == userId }) {
                chatName = user.name
            }
        } else if chatName.isEmpty {
            // Если не задано название группового чата
            chatName = "Групповой чат"
        }

        // Создаем чат
        chatService.createChat(
            name: chatName,
            participants: participants,
            isGroupChat: isGroupChat
        )

        onDismiss()
    }
}

// Структура для представления пользователя
struct UserProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
}

// Строка с информацией о пользователе
struct UserRow: View {
    let user: UserProfile
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack {
                // Аватар пользователя (упрощенная версия)
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 40, height: 40)

                    Text(String(user.name.prefix(1).uppercased()))
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)

                    if !user.email.isEmpty {
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }
}
