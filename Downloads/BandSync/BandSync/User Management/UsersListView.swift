import SwiftUI
import FirebaseFirestore

struct UsersListView: View {
    @State private var users: [(id: String, email: String, role: String)] = []

    var body: some View {
        VStack {
            Text("📋 Users List")
                .font(.title)
                .bold()
                .padding()

            List(users, id: \.id) { user in
                HStack {
                    VStack(alignment: .leading) {
                        Text(user.email)
                            .bold()
                        Text("Role: \(user.role)")
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    Menu {
                        Button("Assign as Admin") {
                            updateUserRole(userID: user.id, newRole: "Admin")
                        }
                        Button("Assign as Manager") {
                            updateUserRole(userID: user.id, newRole: "Manager")
                        }
                        Button("Assign as Musician") {
                            updateUserRole(userID: user.id, newRole: "Musician")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .onAppear {
            fetchUsers()
        }
    }

    /// 📡 Function to load users
    func fetchUsers() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Loading error: \(error.localizedDescription)")
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
        }
    }

    /// 🔥 Function to update user role
    func updateUserRole(userID: String, newRole: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData(["role": newRole]) { error in
            if let error = error {
                print("❌ Role update error: \(error.localizedDescription)")
            } else {
                print("✅ Role updated to \(newRole) for user \(userID)")
                fetchUsers()  // Reload list
            }
        }
    }
}

