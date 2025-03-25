import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MerchandiseSaleView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedItems: [String: Int] = [:]
    @State private var eventId: String? = nil
    @State private var eventTitle: String? = nil
    @State private var saleDate = Date()
    @State private var paymentMethod = "Cash"
    @State private var notes = ""
    @State private var isLoading = true
    @State private var merchandiseItems: [MerchandiseItem] = []
    @State private var events: [Event] = []
    @State private var errorMessage: String? = nil
    
    let paymentMethods = ["Cash", "Card", "Online", "Other"]
    
    var onSaleComplete: (FinanceRecord) -> Void
    
    var totalAmount: Double {
        var total = 0.0
        for (itemId, quantity) in selectedItems {
            if let item = merchandiseItems.first(where: { $0.id == itemId }) {
                total += item.sellingPrice * Double(quantity)
            }
        }
        return total
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section {
                        Text("Loading...")
                        ProgressView()
                    }
                } else {
                    Section(header: Text("Select Merchandise")) {
                        if merchandiseItems.isEmpty {
                            Text("No merchandise items available")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(merchandiseItems) { item in
                                MerchandiseSelectionRow(
                                    item: item,
                                    quantity: selectedItems[item.id] ?? 0,
                                    onQuantityChanged: { newQuantity in
                                        if newQuantity > 0 {
                                            selectedItems[item.id] = newQuantity
                                        } else {
                                            selectedItems.removeValue(forKey: item.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    Section(header: Text("Sale Details")) {
                        DatePicker("Sale Date", selection: $saleDate, displayedComponents: .date)
                        
                        Picker("Payment Method", selection: $paymentMethod) {
                            ForEach(paymentMethods, id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        
                        if !events.isEmpty {
                            Picker("Event", selection: $eventId) {
                                Text("None").tag(String?.none)
                                
                                ForEach(events) { event in
                                    Text(event.title).tag(String?.some(event.id))
                                }
                            }
                            .onChange(of: eventId) { newValue in
                                if let id = newValue,
                                   let event = events.first(where: { $0.id == id }) {
                                    eventTitle = event.title
                                } else {
                                    eventTitle = nil
                                }
                            }
                        }
                        
                        TextField("Notes", text: $notes)
                    }
                    
                    Section(header: Text("Sale Summary")) {
                        HStack {
                            Text("Items Selected")
                            Spacer()
                            Text("\(selectedItems.values.reduce(0, +))")
                        }
                        
                        HStack {
                            Text("Total Amount")
                            Spacer()
                            Text(formatCurrency(totalAmount))
                                .fontWeight(.bold)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section {
                        Button("Record Sale") {
                            recordSale()
                        }
                        .disabled(selectedItems.isEmpty || isLoading)
                    }
                }
            }
            .navigationTitle("Merchandise Sale")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                fetchData()
            }
        }
    }
    
    private func fetchData() {
        isLoading = true
        
        let group = DispatchGroup()
        
        // Fetch merchandise items
        group.enter()
        Firestore.firestore().collection("merchandise").getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                errorMessage = "Error loading merchandise: \(error.localizedDescription)"
                return
            }
            
            merchandiseItems = snapshot?.documents.compactMap { document in
                return MerchandiseItem(document: document)
            } ?? []
        }
        
        // Fetch events
        group.enter()
        Firestore.firestore().collection("events").getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("Error loading events: \(error.localizedDescription)")
                return
            }
            
            events = snapshot?.documents.compactMap { document -> Event? in
                let data = document.data()
                return Event(from: data, id: document.documentID)
            } ?? []
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
    
    private func recordSale() {
        guard !selectedItems.isEmpty else {
            errorMessage = "No items selected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Start a batch to update multiple documents
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Create a description of sold items
        var saleDescription = "Merchandise Sale: "
        var itemDescriptions: [String] = []
        
        for (itemId, quantity) in selectedItems {
            if let item = merchandiseItems.first(where: { $0.id == itemId }) {
                // Update inventory quantity
                let itemRef = db.collection("merchandise").document(itemId)
                let newQuantity = item.quantity - quantity
                
                if newQuantity < 0 {
                    isLoading = false
                    errorMessage = "Not enough stock for \(item.name)"
                    return
                }
                
                batch.updateData(["quantity": newQuantity], forDocument: itemRef)
                
                // Add to description
                itemDescriptions.append("\(quantity)x \(item.name)")
            }
        }
        
        saleDescription += itemDescriptions.joined(separator: ", ")
        
        // Create a finance record for the sale
        let recordId = UUID().uuidString
        let recordRef = db.collection("finances").document(recordId)
        
        var recordData: [String: Any] = [
            "id": recordId,
            "type": "income",
            "amount": totalAmount,
            "currency": "USD",
            "description": saleDescription,
            "category": "Merchandise",
            "date": Timestamp(date: saleDate),
            "paymentMethod": paymentMethod
        ]
        
        if let notes = notes.isEmpty ? nil : notes {
            recordData["notes"] = notes
        }
        
        if let eventId = eventId {
            recordData["eventId"] = eventId
        }
        
        if let eventTitle = eventTitle {
            recordData["eventTitle"] = eventTitle
        }
        
        if let userId = Auth.auth().currentUser?.uid {
            recordData["userId"] = userId
        }
        
        // Add the finance record to the batch
        batch.setData(recordData, forDocument: recordRef)
        
        // Commit the batch
        batch.commit { error in
            isLoading = false
            
            if let error = error {
                errorMessage = "Error recording sale: \(error.localizedDescription)"
                return
            }
            
            // Create the finance record object to return
            let record = FinanceRecord(
                id: recordId,
                type: .income,
                amount: totalAmount,
                currency: "USD",
                description: saleDescription,
                category: "Merchandise",
                date: saleDate,
                eventId: eventId,
                eventTitle: eventTitle
            )
            
            // Call the completion handler
            onSaleComplete(record)
            
            // Dismiss the view
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct MerchandiseSelectionRow: View {
    let item: MerchandiseItem
    let quantity: Int
    let onQuantityChanged: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(item.name)
                .font(.headline)
            
            HStack {
                Text("\(item.category) - \(item.subcategory)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatCurrency(item.sellingPrice))
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("In stock: \(item.quantity)")
                    .font(.caption)
                    .foregroundColor(item.quantity > 0 ? .secondary : .red)
                
                Spacer()
                
                Stepper("\(quantity) selected", value: Binding(
                    get: { self.quantity },
                    set: { self.onQuantityChanged($0) }
                ), in: 0...item.quantity)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
