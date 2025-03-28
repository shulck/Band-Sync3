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
            // Фоновый цвет
            Color(.systemGray6)
                .ignoresSafeArea()
            
            if isLoading {
                EnhancedLoadingView(message: "Loading profile...")
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Фоновый элемент шапки
                        ZStack(alignment: .top) {
                            // Верхний декоративный баннер
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), 
                                        startPoint: .topLeading, 
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 120)
                                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                            
                            // Профильное изображение с данными
                            VStack(spacing: 0) {
                                // Профильное изображение
                                EnhancedProfileImageSection(
                                    profileImage: $profileImage,
                                    isUploading: $isUploadingImage,
                                    showOptions: $showPhotoOptions,
                                    showPicker: $showingImagePicker,
                                    photoSource: $photoSource,
                                    onImageUpload: uploadProfileImage
                                )
                                .padding(.top, 60)
                                
                                // Информация профиля
                                if isEditing {
                                    // Режим редактирования
                                    EnhancedEditProfileSection(
                                        newName: $newName,
                                        newPhone: $newPhone,
                                        onCancel: { isEditing = false },
                                        onSave: saveProfile
                                    )
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                } else {
                                    // Режим просмотра
                                    EnhancedProfileInfoSection(
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
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                }
                            }
                        }
                        
                        if let errorMessage = errorMessage {
                            ErrorMessageView(message: errorMessage)
                                .padding(.horizontal)
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

// Улучшенный индикатор загрузки
struct EnhancedLoadingView: View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

// Отображение сообщения об ошибке
struct ErrorMessageView: View {
    var message: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// Расширение для скругления отдельных углов
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Улучшенная секция изображения профиля
struct EnhancedProfileImageSection: View {
    @Binding var profileImage: UIImage?
    @Binding var isUploading: Bool
    @Binding var showOptions: Bool
    @Binding var showPicker: Bool
    @Binding var photoSource: EnhancedProfileView.PhotoSource
    var onImageUpload: () -> Void
    
    var body: some View {
        ZStack {
            // Фон для изображения
            Circle()
                .fill(Color.white)
                .frame(width: 134, height: 134)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Профиль изображение или плейсхолдер
            Group {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: "person.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(30)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 4)
            )
            
            // Кнопка редактирования
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showOptions = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isUploading)
                    .offset(x: 12, y: 8)
                }
            }
            .frame(width: 120, height: 120)
            
            // Индикатор загрузки
            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 120, height: 120)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .onChange(of: profileImage) { newImage in
            if newImage != nil && !isUploading {
                onImageUpload()
            }
        }
    }
}

// Улучшенная информационная секция профиля
struct EnhancedProfileInfoSection: View {
    var name: String
    var email: String
    var phone: String
    var role: String
    var groupName: String
    var onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Основная информация
            VStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 24, weight: .bold))
                
                // Роль
                HStack(spacing: 8) {
                    Text(role)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    
                    Text(groupName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                        )
                }
            }
            
            // Контактная информация
            VStack(spacing: 16) {
                EnhancedContactCard(icon: "envelope.fill", title: "Email", value: email)
                
                if !phone.isEmpty {
                    EnhancedContactCard(icon: "phone.fill", title: "Phone", value: phone)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
            .padding(.top, 8)
            
            // Кнопка редактирования
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 24)
    }
}

// Карточка контактной информации
struct EnhancedContactCard: View {
    var icon: String
    var title: String
    var value: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

// Улучшенная секция редактирования профиля
struct EnhancedEditProfileSection: View {
    @Binding var newName: String
    @Binding var newPhone: String
    var onCancel: () -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок
            HStack {
                Text("Edit Your Profile")
                    .font(.headline)
                    .bold()
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            // Поля ввода
            VStack(spacing: 16) {
                EnhancedInputField(
                    title: "Full Name",
                    placeholder: "Enter your name",
                    text: $newName,
                    icon: "person.fill"
                )
                
                EnhancedInputField(
                    title: "Phone Number",
                    placeholder: "Enter your phone number",
                    text: $newPhone,
                    icon: "phone.fill",
                    keyboardType: .phonePad
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
            
            // Кнопки действий
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Button(action: onSave) {
                    Text("Save Changes")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            .padding(.top, 16)
        }
        .padding(.bottom, 24)
    }
}

// Поле ввода
struct EnhancedInputField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var icon: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .font(.body)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
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
