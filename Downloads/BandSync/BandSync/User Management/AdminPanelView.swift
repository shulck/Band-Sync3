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
            if isLoading {
                ProgressView("Loading group data...")
            } else {
                VStack {
                    // Group information header
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Group: \(groupName)")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                newGroupName = groupName
                                showingEditGroupName = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            Text("Invite Code: \(groupCode)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                shareGroupCode()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Tab selector
                    Picker("", selection: $selectedTab) {
                        Text("Pending Requests").tag(0)
                        Text("Members").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        if pendingUsers.isEmpty {
                            VStack {
                                Spacer()
                                Text("No pending requests")
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(pendingUsers) { user in
                                    PendingUserRow(user: user, onApprove: {
                                        approveUser(user: user)
                                    }, onReject: {
                                        rejectUser(user: user)
                                    })
                                }
                            }
                        }
                    } else {
                        List {
                            ForEach(activeUsers) { user in
                                ActiveUserRow(user: user, onChangeRole: { newRole in
                                    changeUserRole(user: user, newRole: newRole)
                                }, onRemove: {
                                    removeUser(user: user)
                                })
                            }
                        }
                    }
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
