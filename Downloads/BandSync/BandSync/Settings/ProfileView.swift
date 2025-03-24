import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = ""
    @State private var groupName = ""
    @State private var isEditing = false
    @State private var newName = ""
    @State private var newPhone = ""
    @State private var isLoading = true
    @State private var showingSaveSuccess = false
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading profile...")
            } else {
                Form {
                    Section(header: Text("Profile Information")) {
                        if isEditing {
                            TextField("Name", text: $newName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Phone", text: $newPhone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                        } else {
                            ProfileInfoRow(title: "Name", value: name)
                            ProfileInfoRow(title: "Email", value: email)
                            ProfileInfoRow(title: "Phone", value: phone)
                        }
                    }
                    
                    Section(header: Text("Group Information")) {
                        ProfileInfoRow(title: "Group", value: groupName)
                        ProfileInfoRow(title: "Role", value: role)
                    }
                    
                    if isEditing {
                        Button(action: saveProfile) {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { isEditing = false }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.clear)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            newName = name
                            newPhone = phone
                            isEditing = true
                        }) {
                            Text("Edit Profile")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .alert(isPresented: $showingSaveSuccess) {
                    Alert(
                        title: Text("Profile Updated"),
                        message: Text("Your profile information has been updated successfully."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear(perform: loadUserProfile)
    }
    
    func loadUserProfile() {
        isLoading = true
        
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        email = user.email ?? ""
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error loading profile: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            if let document = document, let data = document.data() {
                self.name = data["name"] as? String ?? ""
                self.phone = data["phone"] as? String ?? ""
                self.role = data["role"] as? String ?? ""
                self.newName = self.name
                self.newPhone = self.phone
                
                // Get group information
                if let groupId = data["groupId"] as? String {
                    db.collection("groups").document(groupId).getDocument { groupDoc, error in
                        if let groupDoc = groupDoc, let groupData = groupDoc.data() {
                            self.groupName = groupData["name"] as? String ?? "Unknown Group"
                        }
                        isLoading = false
                    }
                } else {
                    isLoading = false
                }
            } else {
                isLoading = false
            }
        }
    }
    
    func saveProfile() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData([
            "name": newName,
            "phone": newPhone
        ]) { error in
            if let error = error {
                print("Error updating profile: \(error.localizedDescription)")
            } else {
                // Update display name in Firebase Auth
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = newName
                changeRequest.commitChanges { _ in }
                
                // Update local state
                self.name = self.newName
                self.phone = self.newPhone
                self.isEditing = false
                self.showingSaveSuccess = true
            }
        }
    }
}

struct ProfileInfoRow: View {
    var title: String
    var value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
