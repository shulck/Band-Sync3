import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MerchandiseInventoryView: View {
    @State private var items: [MerchandiseItem] = []
    @State private var isLoading = true
    @State private var showingAddItemSheet = false
    @State private var selectedCategory: String?
    @State private var searchText = ""
    @State private var showingItemDetail: MerchandiseItem? = nil
    @State private var selectedCurrency = "USD"

    // All available merchandise categories
    let categories = ["Clothing", "Accessories", "Music", "Other"]
    // Available currencies
    let currencies = ["USD", "EUR", "UAH"]

    var filteredItems: [MerchandiseItem] {
        var result = items

        if !searchText.isEmpty {
            result = result.filter { item in
                item.name.lowercased().contains(searchText.lowercased()) ||
                item.category.lowercased().contains(searchText.lowercased()) ||
                item.subcategory.lowercased().contains(searchText.lowercased())
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        return result
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading inventory...")
            } else {
                VStack {
                    // Search field
                    TextField("Search merchandise", text: $searchText)
                        .padding(7)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(
                                title: "All",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }

                            ForEach(categories, id: \.self) { category in
                                FilterChip(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = (selectedCategory == category) ? nil : category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    // Inventory summary
                    InventorySummaryView(items: items, currency: selectedCurrency)
                        .padding()

                    // List of items
                    if filteredItems.isEmpty {
                        VStack {
                            Spacer()
                            Text("No merchandise items found")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filteredItems) { item in
                                MerchandiseItemRow(item: item, currency: selectedCurrency)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        showingItemDetail = item
                                    }
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }

                    HStack {
                        Button(action: {
                            showingAddItemSheet = true
                        }) {
                            Text("Add New Item")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Menu {
                            ForEach(currencies, id: \.self) { currency in
                                Button(action: {
                                    selectedCurrency = currency
                                }) {
                                    HStack {
                                        Text(currency)
                                        if selectedCurrency == currency {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCurrency)
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            .padding()
                            .frame(minWidth: 80)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Merchandise Inventory")
        .onAppear {
            fetchInventory()
        }
        .sheet(isPresented: $showingAddItemSheet) {
            AddMerchandiseItemView { newItem in
                addItem(newItem)
            }
        }
        .sheet(item: $showingItemDetail) { item in
            MerchandiseItemDetailView(item: item) { updatedItem in
                updateItem(updatedItem)
            }
        }
    }

    func fetchInventory() {
        isLoading = true

        let db = Firestore.firestore()
        db.collection("merchandise").getDocuments { snapshot, error in
            isLoading = false

            if let error = error {
                print("Error fetching merchandise: \(error.localizedDescription)")
                return
            }

            self.items = snapshot?.documents.compactMap { document in
                return MerchandiseItem(document: document)
            } ?? []
        }
    }

    func addItem(_ item: MerchandiseItem) {
        let db = Firestore.firestore()
        db.collection("merchandise").document(item.id).setData(item.asDictionary) { error in
            if let error = error {
                print("Error adding merchandise item: \(error.localizedDescription)")
            } else {
                // Add to local array
                self.items.append(item)
            }
        }
    }

    func updateItem(_ item: MerchandiseItem) {
        let db = Firestore.firestore()
        db.collection("merchandise").document(item.id).setData(item.asDictionary) { error in
            if let error = error {
                print("Error updating merchandise item: \(error.localizedDescription)")
            } else {
                // Update in local array
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    self.items[index] = item
                }
            }
        }
    }

    func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredItems[$0] }

        let db = Firestore.firestore()
        for item in itemsToDelete {
            db.collection("merchandise").document(item.id).delete { error in
                if let error = error {
                    print("Error deleting merchandise item: \(error.localizedDescription)")
                }
            }
        }

        // Remove from local array
        for item in itemsToDelete {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
        }
    }
}

struct InventorySummaryView: View {
    var items: [MerchandiseItem]
    var currency: String

    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var totalValue: Double {
        items.reduce(0) { $0 + $1.inventoryValue }
    }

    var totalPotentialRevenue: Double {
        items.reduce(0) { $0 + $1.potentialRevenue }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Inventory Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                VStack {
                    Text("Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalItems)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("Cost Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(totalValue))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("Potential Revenue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(totalPotentialRevenue))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct MerchandiseItemRow: View {
    var item: MerchandiseItem
    var currency: String = "USD"

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)

                HStack {
                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(item.subcategory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(item.quantity) units")
                    .font(.subheadline)

                Text(formatPrice(item.sellingPrice))
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }

    func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
}
