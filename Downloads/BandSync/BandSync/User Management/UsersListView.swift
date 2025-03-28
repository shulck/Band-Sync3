import SwiftUI
import FirebaseFirestore

struct UsersListView: View {
    @State private var users: [(id: String, email: String, role: String)] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    var filteredUsers: [(id: String, email: String, role: String)] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { 
                $0.email.localizedCaseInsensitiveContains(searchText) ||
                $0.role.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack {
            // Фоновый цвет для всего экрана
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoading {
                UsersLoadingView()
            } else {
                VStack(spacing: 0) {
                    // Поисковая строка
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search users", text: $searchText)
                            .font(.system(size: 16))
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    
                    // Заголовок с статистикой
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Users")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("\(users.count) total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Счетчики ролей
                        HStack(spacing: 10) {
                            RoleCountBadge(
                                role: "Admin",
                                count: users.filter { $0.role == "Admin" }.count,
                                color: .purple
                            )
                            
                            RoleCountBadge(
                                role: "Manager",
                                count: users.filter { $0.role == "Manager" }.count,
                                color: .blue
                            )
                            
                            RoleCountBadge(
                                role: "Musician",
                                count: users.filter { $0.role == "Musician" }.count,
                                color: .green
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    if filteredUsers.isEmpty {
                        EmptyUserListView(searchText: searchText)
                    } else {
                        List {
                            ForEach(filteredUsers, id: \.id) { user in
                                EnhancedUserRow(
                                    user: user,
                                    onAssignRole: { role in
                                        updateUserRole(userID: user.id, newRole: role)
                                    }
                                )
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .animation(.default, value: filteredUsers.count)
            }
        }
        .navigationTitle("Users Management")
        .onAppear {
            fetchUsers()
        }
    }

    /// Функция для загрузки пользователей
    func fetchUsers() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Loading error: \(error.localizedDescription)")
                isLoading = false
                return
            }

            self.users = snapshot?.documents.map { doc in
                let data = doc.data()
                return (
                    id: doc.documentID,
                    email: data["email"] as? String ?? "No email",
                    role: data["role"] as? String ?? "Unknown"
                )
            } ?? []
            
            isLoading = false
        }
    }

    /// Функция для обновления роли пользователя
    func updateUserRole(userID: String, newRole: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData(["role": newRole]) { error in
            if let error = error {
                print("❌ Role update error: \(error.localizedDescription)")
            } else {
                print("✅ Role updated to \(newRole) for user \(userID)")
                fetchUsers()  // Обновить список
            }
        }
    }
}

// MARK: - Supporting Components

// Улучшенная строка пользователя
struct EnhancedUserRow: View {
    var user: (id: String, email: String, role: String)
    var onAssignRole: (String) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Аватар пользователя
            ZStack {
                Circle()
                    .fill(roleColor(for: user.role).opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(userInitials(from: user.email))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(roleColor(for: user.role))
            }
            
            // Информация о пользователе
            VStack(alignment: .leading, spacing: 4) {
                Text(user.email)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(user.role)
                        .font(.caption)
                        .foregroundColor(roleColor(for: user.role))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(roleColor(for: user.role).opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Кнопка меню
            Menu {
                Button("Assign as Admin") {
                    onAssignRole("Admin")
                }
                Button("Assign as Manager") {
                    onAssignRole("Manager")
                }
                Button("Assign as Musician") {
                    onAssignRole("Musician")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Функция для получения инициалов пользователя из email
    private func userInitials(from email: String) -> String {
        let firstCharacter = email.first?.uppercased() ?? "?"
        return String(firstCharacter)
    }
    
    // Функция для выбора цвета в зависимости от роли
    private func roleColor(for role: String) -> Color {
        switch role {
        case "Admin":
            return .purple
        case "Manager":
            return .blue
        case "Musician":
            return .green
        default:
            return .orange
        }
    }
}

// Бейдж с количеством пользователей по роли
struct RoleCountBadge: View {
    var role: String
    var count: Int
    var color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Text(role)
                .font(.caption2)
                .fontWeight(.semibold)
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(4)
                .background(Circle().fill(color))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

// Пустое состояние
struct EmptyUserListView: View {
    var searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Users Found" : "No Search Results")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ?
                    "There are no users in the system yet" :
                    "No users found matching '\(searchText)'")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// Индикатор загрузки
struct UsersLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: 360))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: UUID()
                    )
            }
            
            Text("Loading users...")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Please wait")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

