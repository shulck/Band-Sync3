import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AdminPanelView: View {
    @State private var pendingUsers: [UserModel] = []
    @State private var activeUsers: [UserModel] = []
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var groupName = ""
    @State private var groupCode = ""
    @State private var showingEditGroupName = false
    @State private var newGroupName = ""
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        ZStack {
            // Фоновый цвет для всего экрана
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                
            if isLoading {
                AdminLoadingView(message: "Loading group data...")
            } else {
                VStack(spacing: 0) {
                    // Группа информационная карточка
                    GroupInfoCard(
                        groupName: groupName, 
                        groupCode: groupCode,
                        onEditName: {
                            newGroupName = groupName
                            showingEditGroupName = true
                        },
                        onShareCode: shareGroupCode
                    )
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Стилизованный селектор вкладок
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            TabButton(
                                title: "Pending Requests",
                                icon: "person.crop.circle.badge.questionmark",
                                isSelected: selectedTab == 0,
                                badgeCount: pendingUsers.count
                            ) {
                                withAnimation { selectedTab = 0 }
                            }
                            
                            TabButton(
                                title: "Members",
                                icon: "person.3.fill",
                                isSelected: selectedTab == 1,
                                badgeCount: nil
                            ) {
                                withAnimation { selectedTab = 1 }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        
                        // Индикатор активной вкладки
                        HStack {
                            Spacer()
                                .frame(width: selectedTab == 0 ? nil : 0)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: UIScreen.main.bounds.width / 2 - 32, height: 3)
                                .cornerRadius(1.5)
                            
                            Spacer()
                                .frame(width: selectedTab == 1 ? nil : 0)
                        }
                        .animation(.spring(), value: selectedTab)
                    }
                    
                    // Содержимое вкладок
                    if selectedTab == 0 {
                        if pendingUsers.isEmpty {
                            EmptyStateView(
                                icon: "person.crop.circle.badge.checkmark",
                                title: "No Pending Requests",
                                message: "When new users request to join your group, they will appear here for approval."
                            )
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(pendingUsers) { user in
                                        EnhancedPendingUserRow(
                                            user: user,
                                            onApprove: { approveUser(user: user) },
                                            onReject: { rejectUser(user: user) }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 16)
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(activeUsers) { user in
                                    EnhancedActiveUserRow(
                                        user: user,
                                        onChangeRole: { newRole in
                                            changeUserRole(user: user, newRole: newRole)
                                        },
                                        onRemove: {
                                            removeUser(user: user)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                        }
                    }
                    
                    Spacer()
                }
                .alert(isPresented: $showingEditGroupName) {
                    Alert(
                        title: Text("Edit Group Name"),
                        message: Text("Enter a new name for your group"),
                        primaryButton: .default(Text("Save")) {
                            if !newGroupName.isEmpty {
                                updateGroupName(newGroupName)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                .refreshable {
                    fetchGroupData()
                    fetchUsers()
                }
            }
        }
        .navigationTitle("Group Management")
        .onAppear {
            fetchGroupData()
            fetchUsers()
        }
    }
    
    // MARK: - Data Methods
    
    // Fetch group data
    func fetchGroupData() {
        isLoading = true
        
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Get user's group ID
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                isLoading = false
                return
            }
            
            // Get group details
            db.collection("groups").document(groupId).getDocument { groupDoc, error in
                if let error = error {
                    print("Error getting group document: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                guard let groupDoc = groupDoc, let groupData = groupDoc.data() else {
                    isLoading = false
                    return
                }
                
                self.groupName = groupData["name"] as? String ?? "Unknown Group"
                self.groupCode = groupData["code"] as? String ?? "ERROR"
                
                isLoading = false
            }
        }
    }

    // Fetch pending and active users
    func fetchUsers() {
        pendingUsers = []
        activeUsers = []
        
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        
        // First get the group ID
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                return
            }
            
            // Now get all users in this group
            db.collection("users").whereField("groupId", isEqualTo: groupId).getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching users: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                // Process all users
                for document in documents {
                    let data = document.data()
                    let user = UserModel(
                        id: document.documentID,
                        email: data["email"] as? String ?? "",
                        name: data["name"] as? String ?? "",
                        role: data["role"] as? String ?? ""
                    )
                    
                    if user.role == "Pending" {
                        self.pendingUsers.append(user)
                    } else {
                        self.activeUsers.append(user)
                    }
                }
                
                // Get pending members from group document as well
                db.collection("groups").document(groupId).getDocument { groupDoc, error in
                    if let error = error {
                        print("Error fetching group: \(error.localizedDescription)")
                        return
                    }
                    
                    if let groupDoc = groupDoc,
                       let pendingMemberIds = groupDoc.data()?["pendingMembers"] as? [String] {
                        // Fetch user details for pending members
                        for memberId in pendingMemberIds {
                            db.collection("users").document(memberId).getDocument { userDoc, error in
                                if let userDoc = userDoc,
                                   let userData = userDoc.data() {
                                    let user = UserModel(
                                        id: userDoc.documentID,
                                        email: userData["email"] as? String ?? "",
                                        name: userData["name"] as? String ?? "",
                                        role: "Pending"
                                    )
                                    
                                    if !self.pendingUsers.contains(where: { $0.id == user.id }) {
                                        self.pendingUsers.append(user)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - User Management Actions
    
    // Approve a pending user
    func approveUser(user: UserModel) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        
        // First get the group ID
        db.collection("users").document(currentUser.uid).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                return
            }
            
            // Update the user's role
            db.collection("users").document(user.id).updateData([
                "role": "Member"
            ]) { error in
                if let error = error {
                    print("Error updating user role: \(error.localizedDescription)")
                } else {
                    // Add the user to the group's members array
                    db.collection("groups").document(groupId).updateData([
                        "members": FieldValue.arrayUnion([user.id]),
                        "pendingMembers": FieldValue.arrayRemove([user.id])
                    ]) { error in
                        if let error = error {
                            print("Error updating group members: \(error.localizedDescription)")
                        } else {
                            // Update our local lists
                            if let index = pendingUsers.firstIndex(where: { $0.id == user.id }) {
                                let updatedUser = UserModel(
                                    id: user.id,
                                    email: user.email,
                                    name: user.name,
                                    role: "Member"
                                )
                                pendingUsers.remove(at: index)
                                activeUsers.append(updatedUser)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Reject a pending user
    func rejectUser(user: UserModel) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        
        // First get the group ID
        db.collection("users").document(currentUser.uid).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                return
            }
            
            // Remove from pending members
            db.collection("groups").document(groupId).updateData([
                "pendingMembers": FieldValue.arrayRemove([user.id])
            ]) { error in
                if let error = error {
                    print("Error removing from pending members: \(error.localizedDescription)")
                } else {
                    // Update the user's document
                    db.collection("users").document(user.id).updateData([
                        "groupId": FieldValue.delete(),
                        "role": "Rejected"
                    ]) { error in
                        if let error = error {
                            print("Error updating user: \(error.localizedDescription)")
                        } else {
                            // Remove from our local list
                            pendingUsers.removeAll(where: { $0.id == user.id })
                        }
                    }
                }
            }
        }
    }
    
    // Change a user's role
    func changeUserRole(user: UserModel, newRole: String) {
        let db = Firestore.firestore()
        
        db.collection("users").document(user.id).updateData([
            "role": newRole
        ]) { error in
            if let error = error {
                print("Error updating user role: \(error.localizedDescription)")
            } else {
                // Update our local list
                if let index = activeUsers.firstIndex(where: { $0.id == user.id }) {
                    activeUsers[index] = UserModel(
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        role: newRole
                    )
                }
            }
        }
    }
    
    // Remove a user from the group
    func removeUser(user: UserModel) {
        guard let currentUser = Auth.auth().currentUser else { return }
        guard user.id != currentUser.uid else {
            // Cannot remove yourself
            return
        }
        
        let db = Firestore.firestore()
        
        // First get the group ID
        db.collection("users").document(currentUser.uid).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                return
            }
            
            // Remove from group members
            db.collection("groups").document(groupId).updateData([
                "members": FieldValue.arrayRemove([user.id])
            ]) { error in
                if let error = error {
                    print("Error removing from members: \(error.localizedDescription)")
                } else {
                    // Update the user's document
                    db.collection("users").document(user.id).updateData([
                        "groupId": FieldValue.delete(),
                        "role": "Removed"
                    ]) { error in
                        if let error = error {
                            print("Error updating user: \(error.localizedDescription)")
                        } else {
                            // Remove from our local list
                            activeUsers.removeAll(where: { $0.id == user.id })
                        }
                    }
                }
            }
        }
    }
    
    // Update the group name
    func updateGroupName(_ name: String) {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        
        // First get the group ID
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                return
            }
            
            // Update the group name
            db.collection("groups").document(groupId).updateData([
                "name": name
            ]) { error in
                if let error = error {
                    print("Error updating group name: \(error.localizedDescription)")
                } else {
                    self.groupName = name
                }
            }
        }
    }
    
    // Share the group code
    func shareGroupCode() {
        let text = "Join my group in BandSync! Use this code: \(groupCode)"
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Components

// Карточка информации о группе
struct GroupInfoCard: View {
    var groupName: String
    var groupCode: String
    var onEditName: () -> Void
    var onShareCode: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Group icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "music.note.list")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(groupName)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Button(action: onEditName) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        }
                    }
                    
                    Text("Music Band")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Invite code section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INVITE CODE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    
                    Text(groupCode)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .padding(.vertical, 4)
                }
                
                Spacer()
                
                Button(action: onShareCode) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// Кнопка вкладки
struct TabButton: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var badgeCount: Int?
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    
                    Text(title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    
                    if let count = badgeCount, count > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                            
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// Улучшенная строка ожидающего пользователя
struct EnhancedPendingUserRow: View {
    var user: UserModel
    var onApprove: () -> Void
    var onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // User avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Text(userInitials(from: user.name))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name.isEmpty ? "Unknown User" : user.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Text("Requested to join")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Action buttons
            HStack(spacing: 10) {
                Button(action: onReject) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: onApprove) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func userInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.isEmpty {
            return "?"
        } else if components.count == 1 {
            return String(components[0].prefix(1).uppercased())
        } else {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
    }
}

// Улучшенная строка активного пользователя
struct EnhancedActiveUserRow: View {
    var user: UserModel
    var onChangeRole: (String) -> Void
    var onRemove: () -> Void
    @State private var showRoleOptions = false
    
    // Доступные роли
    let roles = ["Admin", "Manager", "Member", "Musician"]
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // User avatar
            ZStack {
                Circle()
                    .fill(roleColor(for: user.role).opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(userInitials(from: user.name))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(roleColor(for: user.role))
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name.isEmpty ? "Unknown User" : user.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
            
            // Action menu
            Menu {
                // Role options
                Menu {
                    ForEach(roles, id: \.self) { role in
                        Button(role) {
                            onChangeRole(role)
                        }
                    }
                } label: {
                    Label("Change Role", systemImage: "person.crop.circle.badge.checkmark")
                }
                
                // Remove user option
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove from Group", systemImage: "person.crop.circle.badge.xmark")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func userInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.isEmpty {
            return "?"
        } else if components.count == 1 {
            return String(components[0].prefix(1).uppercased())
        } else {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
    }
    
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

// Пустое состояние
struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
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
struct AdminLoadingView: View {
    var message: String
    
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
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Please wait")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}
