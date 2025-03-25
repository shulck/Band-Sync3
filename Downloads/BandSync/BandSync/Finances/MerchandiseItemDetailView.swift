import SwiftUI
import FirebaseStorage

struct MerchandiseItemDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var item: MerchandiseItem
    var onUpdate: (MerchandiseItem) -> Void
    
    @State private var name: String
    @State private var purchasePrice: String
    @State private var sellingPrice: String
    @State private var quantity: String
    @State private var category: String
    @State private var subcategory: String
    @State private var image: UIImage? = nil
    @State private var imageURL: String?
    @State private var showingImagePicker = false
    @State private var isLoading = true
    @State private var isUploading = false
    @State private var errorMessage: String? = nil
    @State private var showingStockUpdateSheet = false
    @State private var stockChangeAmount = ""
    @State private var stockChangeReason = ""
    
    let categories = ["Clothing", "Accessories", "Music", "Other"]
    let subcategories = [
        "Clothing": ["T-Shirts", "Hoodies", "Hats", "Other"],
        "Accessories": ["Pins", "Stickers", "Patches", "Jewelry", "Other"],
        "Music": ["CD", "Vinyl", "Digital", "Other"],
        "Other": ["Posters", "Artwork", "Miscellaneous"]
    ]
    
    init(item: MerchandiseItem, onUpdate: @escaping (MerchandiseItem) -> Void) {
        self.item = item
        self.onUpdate = onUpdate
        
        // Initialize state variables with item values
        _name = State(initialValue: item.name)
        _purchasePrice = State(initialValue: String(item.purchasePrice))
        _sellingPrice = State(initialValue: String(item.sellingPrice))
        _quantity = State(initialValue: String(item.quantity))
        _category = State(initialValue: item.category)
        _subcategory = State(initialValue: item.subcategory)
        _imageURL = State(initialValue: item.imageURL)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    
                    TextField("Purchase Price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Selling Price", text: $sellingPrice)
                        .keyboardType(.decimalPad)
                    
                    HStack {
                        Text("Current Quantity: \(quantity)")
                        Spacer()
                        Button("Update Stock") {
                            showingStockUpdateSheet = true
                        }
                        .foregroundColor(.blue)
                    }
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
                            Text("Change Image")
                            Spacer()
                            if image != nil || imageURL != nil {
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
                    } else if let imageURL = imageURL, !imageURL.isEmpty {
                        // In a real app, you'd load the image from URL
                        Text("Item has an image")
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("Profitability")) {
                    HStack {
                        Text("Profit Margin")
                        Spacer()
                        Text("$\(String(format: "%.2f", calculateProfitMargin()))")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Margin Percentage")
                        Spacer()
                        Text("\(String(format: "%.1f", calculateMarginPercentage()))%")
                            .foregroundColor(calculateMarginPercentage() >= 30 ? .green : .orange)
                    }
                    
                    HStack {
                        Text("Inventory Value")
                        Spacer()
                        Text("$\(String(format: "%.2f", calculateInventoryValue()))")
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: saveChanges) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .disabled(isUploading || !isFormValid)
                }
            }
            .navigationTitle("Item Details")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $image)
            }
            .sheet(isPresented: $showingStockUpdateSheet) {
                StockUpdateView(
                    currentQuantity: Int(quantity) ?? 0,
                    onUpdate: { newQuantity, reason in
                        self.quantity = String(newQuantity)
                    }
                )
            }
        }
    }
    
    private func calculateProfitMargin() -> Double {
        let purchase = Double(purchasePrice) ?? 0
        let selling = Double(sellingPrice) ?? 0
        return selling - purchase
    }
    
    private func calculateMarginPercentage() -> Double {
        let purchase = Double(purchasePrice) ?? 0
        if purchase == 0 { return 0 }
        
        return (calculateProfitMargin() / purchase) * 100
    }
    
    private func calculateInventoryValue() -> Double {
        let purchase = Double(purchasePrice) ?? 0
        let qty = Double(quantity) ?? 0
        return purchase * qty
    }
    
    private var isFormValid: Bool {
        guard !name.isEmpty,
              let _ = Double(purchasePrice),
              let _ = Double(sellingPrice),
              let _ = Int(quantity),
              !category.isEmpty,
              !subcategory.isEmpty else {
            return false
        }
        
        return true
    }
    
    private func saveChanges() {
        isUploading = true
        errorMessage = nil
        
        // Upload new image if provided
        if let image = image {
            ImageUploadService.uploadImage(image, folder: "merchandise") { result in
                switch result {
                case .success(let url):
                    // Delete old image if exists
                    if let oldUrl = self.imageURL, !oldUrl.isEmpty {
                        ImageUploadService.deleteImage(url: oldUrl) { _ in
                            updateItem(newImageURL: url)
                        }
                    } else {
                        updateItem(newImageURL: url)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        isUploading = false
                        errorMessage = "Image upload error: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            updateItem(newImageURL: imageURL)
        }
    }
    
    private func updateItem(newImageURL: String?) {
        guard let purchasePrice = Double(purchasePrice),
              let sellingPrice = Double(sellingPrice),
              let quantity = Int(quantity) else {
            isUploading = false
            errorMessage = "Invalid input values"
            return
        }
        
        // Create the updated item
        let updatedItem = MerchandiseItem(
            id: item.id,
            name: name,
            purchasePrice: purchasePrice,
            sellingPrice: sellingPrice,
            quantity: quantity,
            category: category,
            subcategory: subcategory,
            imageURL: newImageURL,
            lastUpdated: Date()
        )
        
        // Call the callback
        onUpdate(updatedItem)
        
        // Dismiss the view
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}

struct StockUpdateView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var changeAmount = ""
    @State private var isAddition = true
    @State private var reason = ""
    
    var currentQuantity: Int
    var onUpdate: (Int, String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stock Update")) {
                    Text("Current Quantity: \(currentQuantity)")
                        .font(.headline)
                    
                    Picker("Change Type", selection: $isAddition) {
                        Text("Add Stock").tag(true)
                        Text("Remove Stock").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    TextField("Amount", text: $changeAmount)
                                            .keyboardType(.numberPad)
                                        
                                        TextField("Reason for Change", text: $reason)
                                            .placeholder(when: reason.isEmpty) {
                                                Text("e.g., New stock arrival, Sale at event")
                                                    .foregroundColor(Color(.systemGray4))
                                            }
                                    }
                                    
                                    Section {
                                        Button("Apply Change") {
                                            applyStockChange()
                                        }
                                        .disabled(!isValid)
                                    }
                                }
                                .navigationTitle("Update Stock")
                                .navigationBarItems(trailing: Button("Cancel") {
                                    presentationMode.wrappedValue.dismiss()
                                })
                            }
                        }
                        
                        private var isValid: Bool {
                            guard let amount = Int(changeAmount), amount > 0, !reason.isEmpty else {
                                return false
                            }
                            
                            if !isAddition {
                                // If removing stock, ensure we don't remove more than available
                                return amount <= currentQuantity
                            }
                            
                            return true
                        }
                        
                        private func applyStockChange() {
                            guard let changeValue = Int(changeAmount) else {
                                return
                            }
                            
                            let newQuantity = isAddition ? currentQuantity + changeValue : currentQuantity - changeValue
                            onUpdate(newQuantity, reason)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }

                    extension View {
                        func placeholder<Content: View>(
                            when shouldShow: Bool,
                            alignment: Alignment = .leading,
                            @ViewBuilder placeholder: () -> Content) -> some View {

                            ZStack(alignment: alignment) {
                                placeholder().opacity(shouldShow ? 1 : 0)
                                self
                            }
                        }
                    }
