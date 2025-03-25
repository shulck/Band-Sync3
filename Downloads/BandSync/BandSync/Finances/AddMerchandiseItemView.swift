import SwiftUI
import FirebaseStorage

struct AddMerchandiseItemView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var purchasePrice = ""
    @State private var sellingPrice = ""
    @State private var quantity = ""
    @State private var category = "Clothing"
    @State private var subcategory = ""
    @State private var image: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var isUploading = false
    @State private var errorMessage: String? = nil
    
    let categories = ["Clothing", "Accessories", "Music", "Other"]
    let subcategories = [
        "Clothing": ["T-Shirts", "Hoodies", "Hats", "Other"],
        "Accessories": ["Pins", "Stickers", "Patches", "Jewelry", "Other"],
        "Music": ["CD", "Vinyl", "Digital", "Other"],
        "Other": ["Posters", "Artwork", "Miscellaneous"]
    ]
    
    var onAdd: (MerchandiseItem) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    
                    TextField("Purchase Price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Selling Price", text: $sellingPrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    Picker("Subcategory", selection: $subcategory) {
                        ForEach(subcategories[category] ?? [], id: \.self) { subcategory in
                            Text(subcategory).tag(subcategory)
                        }
                    }
                }
                
                Section(header: Text("Image")) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Text(image == nil ? "Add Image" : "Change Image")
                            Spacer()
                            if image != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: saveItem) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Save Item")
                        }
                    }
                    .disabled(isUploading || !isFormValid)
                }
            }
            .navigationTitle("Add Merchandise")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $image)
            }
        }
    }
    
    private var isFormValid: Bool {
        guard !name.isEmpty,
              let purchasePrice = Double(purchasePrice),
              let sellingPrice = Double(sellingPrice),
              let quantity = Int(quantity),
              !category.isEmpty,
              !subcategory.isEmpty else {
            return false
        }
        
        return true
    }
    
    private func saveItem() {
        isUploading = true
        errorMessage = nil
        
        // Upload image if provided
        if let image = image {
            ImageUploadService.uploadImage(image, folder: "merchandise") { result in
                switch result {
                case .success(let url):
                    createItem(imageURL: url)
                case .failure(let error):
                    DispatchQueue.main.async {
                        isUploading = false
                        errorMessage = "Image upload error: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            createItem(imageURL: nil)
        }
    }
    
    private func createItem(imageURL: String?) {
        guard let purchasePrice = Double(purchasePrice),
              let sellingPrice = Double(sellingPrice),
              let quantity = Int(quantity) else {
            isUploading = false
            errorMessage = "Invalid input values"
            return
        }
        
        // Create the new item
        let newItem = MerchandiseItem(
            id: UUID().uuidString,
            name: name,
            purchasePrice: purchasePrice,
            sellingPrice: sellingPrice,
            quantity: quantity,
            category: category,
            subcategory: subcategory,
            imageURL: imageURL,
            lastUpdated: Date()
        )
        
        // Call the callback
        onAdd(newItem)
        
        // Dismiss the view
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}
