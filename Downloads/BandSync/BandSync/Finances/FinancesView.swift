import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct FinancesView: View {
    @State private var selectedCategory: String?
    @State private var selectedRecord: FinanceRecord?
    @State private var showingEditTransaction = false
    @State private var userRole: String = "Loading..."
    @State private var finances: [FinanceRecord] = []
    @State private var selectedCurrency = "USD"
    @State private var showingAddTransaction = false
    @State private var totalIncome: Double = 0
    @State private var totalExpenses: Double = 0
    @State private var selectedTimeRange: TimeRange = .month
    @State private var searchText = ""

    var currencies = ["USD", "EUR", "UAH"]
    
    var allCategories: [String] {
        Array(Set(finances.map { $0.category })).sorted()
    }
    
    var filteredFinances: [FinanceRecord] {
        var result = finances
        
        // Фильтр по тексту
        if !searchText.isEmpty {
            result = result.filter { record in
                record.description.lowercased().contains(searchText.lowercased()) ||
                record.category.lowercased().contains(searchText.lowercased()) ||
                (record.subcategory ?? "").lowercased().contains(searchText.lowercased()) ||
                (record.eventTitle ?? "").lowercased().contains(searchText.lowercased())
            }
        }
        
        // Фильтр по категории
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        return result
    }
        
    var body: some View {
        NavigationView {
            VStack {
                if userRole == "Admin" || userRole == "Manager" {
                    // Currency Selection
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Time period selection
                    Picker("Time Range", selection: $selectedTimeRange) {
                        Text("Week").tag(TimeRange.week)
                        Text("Month").tag(TimeRange.month)
                        Text("Year").tag(TimeRange.year)
                        Text("All").tag(TimeRange.all)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Financial summary
                    FinanceSummaryView(totalIncome: totalIncome, totalExpenses: totalExpenses, currency: selectedCurrency)
                        .padding()

                    // Income/Expenses chart
                    FinanceChartView(finances: finances)
                        .frame(height: 200)
                        .padding(.horizontal)
                    
                    TextField("Search transactions", text: $searchText)
                        .padding(7)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    CategoryFilterView(selectedCategory: $selectedCategory, categories: allCategories)
                        .padding(.vertical, 8)
                    
                    List {
                        ForEach(filteredFinances) { record in
                            FinanceRecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Показываем экран редактирования при нажатии
                                    selectedRecord = record
                                    showingEditTransaction = true
                                }
                        }
                        .onDelete(perform: deleteRecord)
                    }

                    Button(action: {
                        showingAddTransaction = true
                    }) {
                        Text("Add Transaction")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                } else {
                    Text("No Access")
                        .foregroundColor(.red)
                        .font(.title)
                }
            }
            .navigationTitle("Finances")
            .onAppear {
                fetchUserRole()
                fetchFinances()
            }
            .onChange(of: selectedTimeRange) { _ in
                calculateTotals()
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddFinanceRecordView { newRecord in
                    finances.append(newRecord)
                    saveFinanceRecord(newRecord)
                    calculateTotals()
                }
            }
            .sheet(isPresented: $showingEditTransaction, onDismiss: {
                selectedRecord = nil
            }) {
                if let record = selectedRecord {
                    EditFinanceRecordView(record: record) { updatedRecord in
                        // Обновляем запись в массиве
                        if let index = finances.firstIndex(where: { $0.id == updatedRecord.id }) {
                            finances[index] = updatedRecord
                        }
                    }
                }
            }
        }
    }

    func calculateTotals() {
        let filteredRecords = filterRecordsByTimeRange(finances)
        totalIncome = filteredRecords.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        totalExpenses = filteredRecords.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    func filterRecordsByTimeRange(_ records: [FinanceRecord]) -> [FinanceRecord] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeRange {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return records.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return records.filter { $0.date >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return records.filter { $0.date >= yearAgo }
        case .all:
            return records
        }
    }

    func formatCurrency(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }

    func deleteRecord(at offsets: IndexSet) {
        // Get IDs of records to delete
        let recordsToDelete = offsets.map { finances[$0] }

        // Delete from Firebase
        let db = Firestore.firestore()
        recordsToDelete.forEach { record in
            db.collection("finances").document(record.id).delete { error in
                if let error = error {
                    print("Error deleting record: \(error.localizedDescription)")
                }
            }
        }

        // Delete from local array
        finances.remove(atOffsets: offsets)
        calculateTotals()
    }

    func fetchUserRole() {
        guard let user = Auth.auth().currentUser else {
            userRole = "Not Authorized"
            return
        }

        let db = Firestore.firestore()
        db.collection("users").whereField("email", isEqualTo: user.email ?? "").getDocuments { snapshot, error in
            if let snapshot = snapshot, let document = snapshot.documents.first {
                self.userRole = document.data()["role"] as? String ?? "Unknown Role"
            } else {
                self.userRole = "Error Loading"
            }
        }
    }

    func fetchFinances() {
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        db.collection("finances")
            .whereField("userId", isEqualTo: user.uid)
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching finances: \(error.localizedDescription)")
                    return
                }

                if let snapshot = snapshot {
                    self.finances = snapshot.documents.compactMap { document -> FinanceRecord? in
                        let data = document.data()

                        guard let typeString = data["type"] as? String,
                              let amount = data["amount"] as? Double,
                              let currency = data["currency"] as? String,
                              let description = data["description"] as? String,
                              let category = data["category"] as? String,
                              let timestamp = data["date"] as? Timestamp else {
                            return nil
                        }

                        let type: FinanceType = typeString == "income" ? FinanceType.income : FinanceType.expense
                        let date = timestamp.dateValue()
                        let receiptImageURL = data["receiptImageURL"] as? String
                        let eventId = data["eventId"] as? String
                        let eventTitle = data["eventTitle"] as? String
                        let subcategory = data["subcategory"] as? String
                        let tags = data["tags"] as? [String]

                        return FinanceRecord(
                            id: document.documentID,
                            type: type,
                            amount: amount,
                            currency: currency,
                            description: description,
                            category: category,
                            date: date,
                            receiptImageURL: receiptImageURL,
                            eventId: eventId,
                            eventTitle: eventTitle,
                            subcategory: subcategory,
                            tags: tags
                        )
                    }
                    
                    // Sort by date
                    self.finances = self.finances.sorted(by: { $0.date > $1.date })

                    // If no data, load demo data
                    if self.finances.isEmpty {
                        // Uncomment if you want demo data
                        // self.loadDemoData()
                    }

                    self.calculateTotals()
                }
            }
    }

    func loadDemoData() {
        let now = Date()
        let calendar = Calendar.current

        let demoData: [FinanceRecord] = [
            FinanceRecord(
                id: "1",
                type: .income,
                amount: 1200,
                currency: "USD",
                description: "Concert at Club X",
                category: "Gig",
                date: now,
                receiptImageURL: nil,
                eventId: nil,
                eventTitle: nil,
                subcategory: nil,
                tags: nil
            ),
            FinanceRecord(
                id: "2",
                type: .expense,
                amount: 300,
                currency: "USD",
                description: "Transportation",
                category: "Logistics",
                date: calendar.date(byAdding: .day, value: -2, to: now)!,
                receiptImageURL: nil,
                eventId: nil,
                eventTitle: nil,
                subcategory: nil,
                tags: nil
            ),
            FinanceRecord(
                id: "3",
                type: .expense,
                amount: 180,
                currency: "USD",
                description: "Hotel",
                category: "Accommodation",
                date: calendar.date(byAdding: .day, value: -2, to: now)!,
                receiptImageURL: nil,
                eventId: nil,
                eventTitle: nil,
                subcategory: nil,
                tags: nil
            ),
            FinanceRecord(
                id: "4",
                type: .income,
                amount: 950,
                currency: "USD",
                description: "Festival Performance",
                category: "Gig",
                date: calendar.date(byAdding: .day, value: -10, to: now)!,
                receiptImageURL: nil,
                eventId: nil,
                eventTitle: nil,
                subcategory: nil,
                tags: nil
            ),
            FinanceRecord(
                id: "5",
                type: .expense,
                amount: 120,
                currency: "USD",
                description: "Equipment Rental",
                category: "Equipment",
                date: calendar.date(byAdding: .day, value: -12, to: now)!,
                receiptImageURL: nil,
                eventId: nil,
                eventTitle: nil,
                subcategory: nil,
                tags: nil
            ),
            FinanceRecord(
                id: "6",
                type: .income,
                amount: 350,
                currency: "USD",
                description: "Merchandise Sales",
                category: "Merchandise",
                date: calendar.date(byAdding: .day, value: -15, to: now)!,
                receiptImageURL: nil,
                eventId: nil,
                eventTitle: "Local Music Fair",
                subcategory: "T-Shirts",
                tags: ["merchandise", "sales"]
            )
        ]

        finances = demoData
    }

    func saveFinanceRecord(_ record: FinanceRecord) {
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        var data: [String: Any] = [
            "userId": user.uid,
            "type": record.type == .income ? "income" : "expense",
            "amount": record.amount,
            "currency": record.currency,
            "description": record.description,
            "category": record.category,
            "date": Timestamp(date: record.date)
        ]

        if let receiptImageURL = record.receiptImageURL {
            data["receiptImageURL"] = receiptImageURL
        }
        
        if let eventId = record.eventId {
            data["eventId"] = eventId
        }
        
        if let eventTitle = record.eventTitle {
            data["eventTitle"] = eventTitle
        }
        
        if let subcategory = record.subcategory {
            data["subcategory"] = subcategory
        }
        
        if let tags = record.tags {
            data["tags"] = tags
        }

        db.collection("finances").document(record.id).setData(data) { error in
            if let error = error {
                print("Error saving finance record: \(error.localizedDescription)")
            }
        }
    }
}

// Time range for data filtering
enum TimeRange {
    case week, month, year, all
}

// View for displaying financial summary
struct FinanceSummaryView: View {
    var totalIncome: Double
    var totalExpenses: Double
    var currency: String

    var profit: Double {
        totalIncome - totalExpenses
    }

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                VStack {
                    Text("Income")
                        .font(.headline)
                    Text(formatCurrency(amount: totalIncome, currency: currency))
                        .foregroundColor(.green)
                }

                Divider()

                VStack {
                    Text("Expenses")
                        .font(.headline)
                    Text(formatCurrency(amount: totalExpenses, currency: currency))
                        .foregroundColor(.red)
                }

                Divider()

                VStack {
                    Text("Profit")
                        .font(.headline)
                    Text(formatCurrency(amount: profit, currency: currency))
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }

    func formatCurrency(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}

// Income and expenses chart
struct FinanceChartView: View {
    var finances: [FinanceRecord]

    // Prepare data for the chart
    var chartData: [(date: Date, income: Double, expense: Double)] {
        // Group records by date (day)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var groupedData: [String: (income: Double, expense: Double)] = [:]

        // Initialize data for the last 7 days
        let calendar = Calendar.current
        let today = Date()

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateString = dateFormatter.string(from: date)
                groupedData[dateString] = (0, 0)
            }
        }

        // Sum up income and expenses for each day
        for record in finances {
            let dateString = dateFormatter.string(from: record.date)

            var existingData = groupedData[dateString] ?? (0, 0)

            if record.type == .income {
                existingData.income += record.amount
            } else {
                existingData.expense += record.amount
            }

            groupedData[dateString] = existingData
        }

        // Convert to array for the chart, sorted by date
        return groupedData.map { (dateString, values) -> (date: Date, income: Double, expense: Double) in
            let date = dateFormatter.date(from: dateString) ?? Date()
            return (date, values.income, values.expense)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack {
            // Implement chart using SwiftUI
            // In a real app, a library like Charts would be used here
            HStack(alignment: .bottom, spacing: 15) {
                ForEach(chartData, id: \.date) { dataPoint in
                    VStack(spacing: 4) {
                        Text(formatDate(dataPoint.date))
                            .font(.caption)
                            .rotationEffect(.degrees(-45))
                            .frame(width: 30)

                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 15, height: scaledHeight(dataPoint.income))

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 15, height: scaledHeight(dataPoint.expense))
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(.top, 20)

            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Income")
                    .font(.caption)

                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("Expense")
                    .font(.caption)
            }
        }
    }

    // Helper for scaling bar heights
    func scaledHeight(_ value: Double) -> CGFloat {
        let maxValue = chartData.flatMap { [$0.income, $0.expense] }.max() ?? 1
        let scale = 150.0 / maxValue
        return CGFloat(value * scale)
    }

    // Helper for formatting date
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

// View for adding a financial record
struct AddFinanceRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var transactionType: FinanceType = .income
    @State private var amount = ""
    @State private var description = ""
    @State private var category = ""
    @State private var subcategory = ""
    @State private var currency = "USD"
    @State private var date = Date()
    @State private var showImagePicker = false
    @State private var receiptImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var currencies = ["USD", "EUR", "UAH"]

    var incomeCategories = ["Gig", "Merchandise", "Royalties", "Sponsorship", "Other"]
    var expenseCategories = ["Logistics", "Accommodation", "Food", "Equipment", "Promotion", "Fees", "Other"]
    var merchandiseSubcategories = ["T-Shirts", "Hoodies", "Hats", "Pins/Stickers", "CDs/Vinyl", "Posters", "Other"]

    var onAdd: (FinanceRecord) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transaction Type")) {
                    Picker("Type", selection: $transactionType) {
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
                        ForEach(transactionType == .income ? incomeCategories : expenseCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    // If category is Merchandise, show subcategories
                    if category == "Merchandise" {
                        Picker("Subcategory", selection: $subcategory) {
                            Text("None").tag("")
                            ForEach(merchandiseSubcategories, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section(header: Text("Receipt/Invoice")) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Text(receiptImage == nil ? "Add Receipt Image" : "Change Receipt Image")
                            Spacer()
                            if receiptImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if receiptImage != nil {
                        Image(uiImage: receiptImage!)
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
                    Button(action: saveTransaction) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Save Transaction")
                        }
                    }
                    .disabled(!isFormValid || isUploading)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $receiptImage)
            }
            .onChange(of: transactionType) { _ in
                // Reset category when transaction type changes
                category = ""
                subcategory = ""
            }
        }
    }

    var isFormValid: Bool {
        let amountValue = Double(amount) ?? 0
        return !description.isEmpty && !category.isEmpty && amountValue > 0
    }

    func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        isUploading = true
        errorMessage = nil
        
        // If we have an image, upload it first
        if let image = receiptImage {
            uploadImage(image) { url in
                if let url = url {
                    createRecord(receiptURL: url)
                } else {
                    isUploading = false
                    errorMessage = "Failed to upload image. Please try again."
                }
            }
        } else {
            createRecord(receiptURL: nil)
        }
    }
    
    func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
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
    
    func createRecord(receiptURL: String?) {
        guard let amountValue = Double(amount) else {
            isUploading = false
            return
        }
        
        // Create the new record
        let newRecord = FinanceRecord(
            id: UUID().uuidString,
            type: transactionType,
            amount: amountValue,
            currency: currency,
            description: description,
            category: category,
            date: date,
            receiptImageURL: receiptURL,
            eventId: nil,
            eventTitle: nil,
            subcategory: category == "Merchandise" && !subcategory.isEmpty ? subcategory : nil,
            tags: nil
        )
        
        // Pass the record back through the callback
        onAdd(newRecord)
        
        // Dismiss the form
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}

// Image picker component
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update
    }
    
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
