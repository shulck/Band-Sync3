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
            Form {
                Section(header: Text("Chat Type")) {
                    Toggle("Group chat", isOn: $isGroupChat)
                }

                if isGroupChat {
                    Section(header: Text("Chat Name")) {
                        TextField("Enter chat name", text: $chatName)
                    }
                }

                Section(header: Text("Participants")) {
                    if !selectedUsers.isEmpty {
                        List {
                            ForEach(selectedUsers) { user in
                                HStack {
                                    Text(user.name)
                                    Spacer()
                                    Button(action: {
                                        selectedUsers.removeAll { $0.id == user.id }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Available Users")) {
                    ForEach(filteredUsers) { user in
                        if !selectedUsers.contains(where: { $0.id == user.id }) &&
                           user.id != chatService.currentUserId {
                            HStack {
                                Text(user.name)
                                Spacer()
                                Button(action: {
                                    selectedUsers.append(user)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search users")

                Section {
                    Button(action: createChat) {
                        if isCreatingChat {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create chat")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                    }
                    .disabled(!isFormValid || isCreatingChat)
                }
            }
            .navigationTitle("New Chat")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
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
