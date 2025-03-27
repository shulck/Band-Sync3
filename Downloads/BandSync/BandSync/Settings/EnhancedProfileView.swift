import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct EnhancedProfileView: View {
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
    @State private var showPhotoOptions = false
    @State private var showingImagePicker = false
    @State private var profileImage: UIImage?
    @State private var isUploadingImage = false
    @State private var errorMessage: String?
    @State private var photoSource: PhotoSource = .photoLibrary
    
    enum PhotoSource {
        case camera, photoLibrary
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "Loading profile...")
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Image
                        ProfileImageSection(
                            profileImage: $profileImage,
                            isUploading: $isUploadingImage,
                            showOptions: $showPhotoOptions,
                            showPicker: $showingImagePicker,
                            photoSource: $photoSource,
                            onImageUpload: uploadProfileImage
                        )
                        
                        // Profile Information
                        if isEditing {
                            // Edit mode
                            EditProfileSection(
                                newName: $newName,
                                newPhone: $newPhone,
                                onCancel: { isEditing = false },
                                onSave: saveProfile
                            )
                        } else {
                            // View mode
                            ProfileInfoSection(
                                name: name,
                                email: email,
                                phone: phone,
                                role: role,
                                groupName: groupName,
                                onEdit: {
                                    newName = name
                                    newPhone = phone
                                    isEditing = true
                                }
                            )
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .alert(isPresented: $showingSaveSuccess) {
                    Alert(
                        title: Text("Profile Updated"),
                        message: Text("Your profile information has been updated successfully."),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .sheet(isPresented: $showingImagePicker) {
                    if photoSource == .camera {
                        CustomImagePicker(image: $profileImage, sourceType: .camera)
                    } else {
                        CustomImagePicker(image: $profileImage, sourceType: .photoLibrary)
                    }
                }
                .actionSheet(isPresented: $showPhotoOptions) {
                    ActionSheet(
                        title: Text("Change Profile Picture"),
                        buttons: [
                            .default(Text("Take Photo")) {
                                photoSource = .camera
                                showingImagePicker = true
                            },
                            .default(Text("Choose from Library")) {
                                photoSource = .photoLibrary
                                showingImagePicker = true
                            },
                            .destructive(Text("Remove Photo")) {
                                removeProfileImage()
                            },
                            .cancel()
                        ]
                    )
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear(perform: loadUserProfile)
    }
    
    // MARK: - Data Loading & Actions
    
    func loadUserProfile() {
        isLoading = true
        errorMessage = nil
        
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "User not logged in"
            return
        }
        
        email = user.email ?? ""
        
        // Load profile image
        if let photoURL = user.photoURL {
            loadProfileImage(from: photoURL)
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error loading profile: \(error.localizedDescription)")
                errorMessage = "Error loading profile: \(error.localizedDescription)"
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
                    self.groupName = "No Group"
                    isLoading = false
                }
            } else {
                errorMessage = "No user data found"
                isLoading = false
            }
        }
    }
    
    func saveProfile() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in"
            return
        }
        
        // Show loading indicator
        isLoading = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData([
            "name": newName,
            "phone": newPhone
        ]) { error in
            if let error = error {
                print("Error updating profile: \(error.localizedDescription)")
                errorMessage = "Error updating profile: \(error.localizedDescription)"
                isLoading = false
                return
            }
            
            // Update display name in Firebase Auth
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = newName
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Error updating display name: \(error.localizedDescription)")
                    errorMessage = "Error updating display name"
                    isLoading = false
                    return
                }
                
                // Update local state
                self.name = self.newName
                self.phone = self.newPhone
                self.isEditing = false
                self.showingSaveSuccess = true
                self.isLoading = false
            }
        }
    }
    
    func loadProfileImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = image
                }
            } else if let error = error {
                print("Error loading profile image: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func uploadProfileImage() {
        guard let user = Auth.auth().currentUser, let image = profileImage else {
            return
        }
        
        isUploadingImage = true
        errorMessage = nil
        
        // Resize and compress image for storage efficiency
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            errorMessage = "Failed to process image"
            isUploadingImage = false
            return
        }
        
        // Create storage reference
        let storageRef = Storage.storage().reference().child("profile_images/\(user.uid).jpg")
        
        // Upload the image
        let metaData = StorageMetadata()
        metaData.contentType = "image/jpeg"
        
        let uploadTask = storageRef.putData(imageData, metadata: metaData) { _, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to upload image"
                    self.isUploadingImage = false
                }
                return
            }
            
            // Get download URL
            storageRef.downloadURL { url, error in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                    
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        self.errorMessage = "Failed to process uploaded image"
                        return
                    }
                    
                    guard let downloadURL = url else {
                        self.errorMessage = "Failed to get image URL"
                        return
                    }
                    
                    // Update user profile with photo URL
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.photoURL = downloadURL
                    changeRequest.commitChanges { error in
                        if let error = error {
                            print("Error updating profile photo: \(error.localizedDescription)")
                            self.errorMessage = "Failed to update profile photo"
                        } else {
                            // Show success message
                            self.showingSaveSuccess = true
                        }
                    }
                }
            }
        }
        
        uploadTask.observe(.progress) { snapshot in
            // Could add progress reporting here if wanted
        }
    }
    
    func removeProfileImage() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        isUploadingImage = true
        
        // Remove from storage if exists
        if let photoURL = user.photoURL {
            let storageRef = Storage.storage().reference(forURL: photoURL.absoluteString)
            storageRef.delete { error in
                if let error = error {
                    print("Error removing profile image: \(error.localizedDescription)")
                    // Continue anyway since we want to remove from user profile
                }
                
                // Now update the user profile
                updateUserWithoutPhoto(user: user)
            }
        } else {
            // Just update the user profile
            updateUserWithoutPhoto(user: user)
        }
    }
    
    private func updateUserWithoutPhoto(user: User) {
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.photoURL = nil
        changeRequest.commitChanges { error in
            DispatchQueue.main.async {
                self.isUploadingImage = false
                
                if let error = error {
                    print("Error updating profile: \(error.localizedDescription)")
                    self.errorMessage = "Failed to remove profile photo"
                } else {
                    self.profileImage = nil
                }
            }
        }
    }
}

// MARK: - Supporting Components

// Loading View
struct LoadingView: View {
    var message: String
    
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.9))
    }
}

// Profile Image Section
struct ProfileImageSection: View {
    @Binding var profileImage: UIImage?
    @Binding var isUploading: Bool
    @Binding var showOptions: Bool
    @Binding var showPicker: Bool
    @Binding var photoSource: EnhancedProfileView.PhotoSource
    var onImageUpload: () -> Void
    
    var body: some View {
        ZStack {
            // Profile image or placeholder
            Group {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(30)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 120, height: 120)
            .background(Color.blue.opacity(0.3))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .shadow(radius: 3)
            )
            
            // Edit button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showOptions = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .disabled(isUploading)
                }
            }
            .frame(width: 120, height: 120)
            
            // Upload indicator overlay
            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 120, height: 120)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    )
            }
        }
        .padding(.vertical)
        .onChange(of: profileImage) { newImage in
            if newImage != nil && !isUploading {
                onImageUpload()
            }
        }
    }
}

// Profile Info Section
struct ProfileInfoSection: View {
    var name: String
    var email: String
    var phone: String
    var role: String
    var groupName: String
    var onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // User Info Card
            VStack(spacing: 12) {
                Text(name)
                    .font(.title)
                    .bold()
                
                Text(role)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                
                Text(groupName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Contact Info Card
            VStack(alignment: .leading, spacing: 16) {
                Text("Contact Information")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                ContactInfoRow(icon: "envelope", title: "Email", value: email)
                
                if !phone.isEmpty {
                    ContactInfoRow(icon: "phone", title: "Phone", value: phone)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Edit Button
            Button(action: onEdit) {
                Text("Edit Profile")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 16)
        }
    }
}

// Contact Info Row
struct ContactInfoRow: View {
    var icon: String
    var title: String
    var value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.callout)
            }
        }
    }
}

// Edit Profile Section
struct EditProfileSection: View {
    @Binding var newName: String
    @Binding var newPhone: String
    var onCancel: () -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Form Fields
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Profile")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("Your name", text: $newName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("Your phone number", text: $newPhone)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: onSave) {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// Image Picker
struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CustomImagePicker
        
        init(_ parent: CustomImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
