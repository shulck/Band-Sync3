import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NewChatView: View {
    let chatService: ChatService
    @Environment(\.presentationMode) var presentationMode

    @State private var chatName = ""
    @State private var isGroupChat = false
    @State private var selectedUsers: [UserInfo] = []
    @State private var availableUsers: [UserInfo] = []
    @State private var searchText = ""
    @State private var isCreatingChat = false

    var filteredUsers: [UserInfo] {
        if searchText.isEmpty {
            return availableUsers
        } else {
            return availableUsers.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.email.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)

                Form {
                    Section(header: Text("Тип чата").font(.subheadline)) {
                        Toggle(isOn: $isGroupChat) {
                            HStack {
                                Image(systemName: isGroupChat ? "person.3.fill" : "person.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                                    .frame(width: 30)

                                Text(isGroupChat ? "Групповой чат" : "Личный чат")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.vertical, 4)
                    }

                    if isGroupChat {
                        Section(header: Text("Название чата").font(.subheadline)) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                                    .frame(width: 30)

                                TextField("Введите название чата", text: $chatName)
                                    .font(.system(size: 16))
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !selectedUsers.isEmpty {
                        Section(header: Text("Выбранные участники (\(selectedUsers.count))").font(.subheadline)) {
                            ForEach(selectedUsers) { user in
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [.blue.opacity(0.7), .blue]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing))
                                            .frame(width: 36, height: 36)

                                        Text(String(user.name.prefix(1)).uppercased())
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)

                                    Text(user.name)
                                        .font(.system(size: 16))

                                    Spacer()

                                    Button(action: {
                                        selectedUsers.removeAll { $0.id == user.id }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section(header:
                        HStack {
                            Text("Доступные пользователи")
                                .font(.subheadline)

                            Spacer()

                            Text("\(filteredUsers.count) из \(availableUsers.count)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    ) {
                        ForEach(filteredUsers) { user in
                            if !selectedUsers.contains(where: { $0.id == user.id }) &&
                               user.id != chatService.currentUserId {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 36, height: 36)

                                        Text(String(user.name.prefix(1)).uppercased())
                                            .foregroundColor(.gray)
                                            .font(.system(size: 16, weight: .semibold))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.name)
                                            .font(.system(size: 16))

                                        if !user.email.isEmpty {
                                            Text(user.email)
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Spacer()

                                    Button(action: {
                                        selectedUsers.append(user)
                                        // Добавляем тактильный отклик
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Поиск по имени или email")

                    Section {
                        Button(action: createChat) {
                            HStack {
                                Spacer()

                                if isCreatingChat {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .frame(height: 24)
                                } else {
                                    Text("Создать чат")
                                        .font(.system(size: 16, weight: .semibold))
                                }

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isFormValid && !isCreatingChat ?
                                        LinearGradient(gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]), startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(isFormValid && !isCreatingChat ? .white : .gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || isCreatingChat)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                }
            }
            .navigationTitle("Новый чат")
            .navigationBarItems(trailing: Button("Отмена") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
            )
            .onAppear {
                fetchUsers()
            }
        }
    }

    private var isFormValid: Bool {
        if selectedUsers.isEmpty {
            return false
        }

        if isGroupChat && chatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        return true
    }

    private func createChat() {
        isCreatingChat = true
        let userIds = selectedUsers.map { $0.id }

        if isGroupChat {
            // Групповой чат с заданным именем
            chatService.createChat(
                name: chatName.trimmingCharacters(in: .whitespacesAndNewlines),
                participants: userIds,
                isGroupChat: true
            )
        } else if let firstUser = selectedUsers.first {
            // Личный чат - используем имя пользователя
            chatService.createChat(
                name: firstUser.name,
                participants: [firstUser.id],
                isGroupChat: false
            )
        }

        // Даем время Firebase обработать запрос
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isCreatingChat = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func fetchUsers() {
        let db = Firestore.firestore()
        print("🔄 Loading users...")

        // Сначала получим группу текущего пользователя
        guard let currentUserId = chatService.currentUserId else { return }

        db.collection("users").document(currentUserId).getDocument { document, error in
            if let error = error {
                print("⛔️ Error getting user data: \(error.localizedDescription)")
                return
            }

            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                print("⛔️ Failed to get user group")
                return
            }

            // Теперь получаем всех пользователей в этой группе
            db.collection("users").whereField("groupId", isEqualTo: groupId).getDocuments { snapshot, error in
                if let error = error {
                    print("⛔️ Error getting users: \(error.localizedDescription)")
                    return
                }

                if let documents = snapshot?.documents {
                    print("✅ Got \(documents.count) users")

                    availableUsers = documents.compactMap { document -> UserInfo? in
                        let data = document.data()

                        let name = data["name"] as? String ?? data["email"] as? String ?? "User"
                        let email = data["email"] as? String ?? ""

                        return UserInfo(
                            id: document.documentID,
                            name: name,
                            email: email
                        )
                    }

                    print("📝 Available users: \(availableUsers.count)")
                }
            }
        }
    }
}
