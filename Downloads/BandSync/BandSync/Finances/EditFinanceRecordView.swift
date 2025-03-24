import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct EditFinanceRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Исходная запись для редактирования
    var record: FinanceRecord
    // Callback после сохранения
    var onSave: (FinanceRecord) -> Void
    
    // Состояние для полей формы
    @State private var type: FinanceType
    @State private var amount: String
    @State private var description: String
    @State private var category: String
    @State private var currency: String
    @State private var date: Date
    @State private var receiptImage: UIImage?
    @State private var receiptImageURL: String?
    @State private var showingImagePicker = false
    @State private var subcategory: String = ""
    @State private var eventId: String?
    @State private var eventTitle: String?
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    // Доступные категории
    let incomeCategories = ["Gig", "Merchandise", "Royalties", "Sponsorship", "Other"]
    let expenseCategories = ["Logistics", "Accommodation", "Food", "Equipment", "Promotion", "Fees", "Other"]
    let merchandiseSubcategories = ["T-Shirts", "Hoodies", "Hats", "Pins/Stickers", "CDs/Vinyl", "Posters", "Other"]
    let currencies = ["USD", "EUR", "UAH", "GBP"]
    
    // Инициализатор для установки начальных значений
    init(record: FinanceRecord, onSave: @escaping (FinanceRecord) -> Void) {
        self.record = record
        self.onSave = onSave
        
        // Устанавливаем начальные значения
        _type = State(initialValue: record.type)
        _amount = State(initialValue: String(record.amount))
        _description = State(initialValue: record.description)
        _category = State(initialValue: record.category)
        _currency = State(initialValue: record.currency)
        _date = State(initialValue: record.date)
        _receiptImageURL = State(initialValue: record.receiptImageURL)
        _subcategory = State(initialValue: record.subcategory ?? "")
        _eventId = State(initialValue: record.eventId)
        _eventTitle = State(initialValue: record.eventTitle)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transaction Type")) {
                    Picker("Type", selection: $type) {
                        Text("Income").tag(FinanceType.income)
                        Text("Expense").tag(FinanceType.expense)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Details")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    
                    TextField("Description", text: $description)
                    
                    Picker("Category", selection: $category) {
                        ForEach(type == .income ? incomeCategories : expenseCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    // Если выбрана категория Merchandise, показываем подкатегории
                    if category == "Merchandise" {
                        Picker("Subcategory", selection: $subcategory) {
                            Text("None").tag("")
                            ForEach(merchandiseSubcategories, id: \.self) { subcategory in
                                Text(subcategory).tag(subcategory)
                            }
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Receipt/Invoice")) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Text(receiptImage != nil || receiptImageURL != nil ? "Change Receipt Image" : "Add Receipt Image")
                            Spacer()
                            if receiptImage != nil || receiptImageURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    } else if let urlString = receiptImageURL, !urlString.isEmpty {
                        // Здесь можно добавить загрузку изображения по URL, но для простоты показываем текст
                        Text("Receipt image available")
                            .foregroundColor(.green)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: saveTransaction) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .disabled(isUploading || !isFormValid)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $receiptImage)
            }
        }
    }
    
    private var isFormValid: Bool {
        let amountValue = Double(amount) ?? 0
        return !description.isEmpty && !category.isEmpty && amountValue > 0
    }
    
    private func saveTransaction() {
        isUploading = true
        errorMessage = nil
        
        // Если у нас есть новое изображение, загружаем его
        if let image = receiptImage {
            uploadReceiptImage(image) { url in
                if let url = url {
                    // Обновляем URL и сохраняем транзакцию
                    saveFinanceRecord(imageURL: url)
                } else {
                    // Обрабатываем ошибку загрузки
                    isUploading = false
                    errorMessage = "Failed to upload image. Please try again."
                }
            }
        } else {
            // Если нет нового изображения, просто обновляем запись
            saveFinanceRecord(imageURL: receiptImageURL)
        }
    }
    
    private func uploadReceiptImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference().child("receipts/\(UUID().uuidString).jpg")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                completion(url?.absoluteString)
            }
        }
    }
    
    private func saveFinanceRecord(imageURL: String?) {
        guard let amountValue = Double(amount) else {
            isUploading = false
            errorMessage = "Invalid amount"
            return
        }
        
        // Создаем обновленную запись
        var updatedRecord = record
        updatedRecord.type = type
        updatedRecord.amount = amountValue
        updatedRecord.description = description
        updatedRecord.category = category
        updatedRecord.currency = currency
        updatedRecord.date = date
        updatedRecord.receiptImageURL = imageURL
        updatedRecord.subcategory = category == "Merchandise" ? (subcategory.isEmpty ? nil : subcategory) : nil
        
        // Сохраняем в Firebase
        let db = Firestore.firestore()
        db.collection("finances").document(record.id).setData([
            "type": type == .income ? "income" : "expense",
            "amount": amountValue,
            "description": description,
            "category": category,
            "subcategory": category == "Merchandise" ? subcategory : NSNull(),
            "currency": currency,
            "date": Timestamp(date: date),
            "receiptImageURL": imageURL ?? NSNull(),
            "eventId": eventId ?? NSNull(),
            "eventTitle": eventTitle ?? NSNull()
        ]) { error in
            isUploading = false
            
            if let error = error {
                errorMessage = "Error: \(error.localizedDescription)"
            } else {
                // Вызываем колбэк и закрываем форму
                onSave(updatedRecord)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// ImagePicker для выбора изображения
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
