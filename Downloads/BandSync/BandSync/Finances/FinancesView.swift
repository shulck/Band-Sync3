import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct FinancesView: View {
    @State private var isLoading = true
    @State private var showingMerchandiseSale = false
    @State private var selectedCategory: String?
    @State private var selectedEvent: Event? = nil
    @State private var events: [Event] = []
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
    
    func fetchEvents() {
        let db = Firestore.firestore()
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching events: \(error.localizedDescription)")
                return
            }

            events = snapshot?.documents.compactMap { document -> Event? in
                let data = document.data()
                return Event(from: data, id: document.documentID)
            } ?? []
        }
    }

    struct EventFilterChip: View {
        var title: String
        var isSelected: Bool
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack {
                    Text(title)
                        .lineLimit(1)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .shadow(color: isSelected ? Color.blue.opacity(0.2) : Color.clear, radius: 2)
            }
        }
    }

    var currencies = ["USD", "EUR", "UAH"]

    var allCategories: [String] {
        Array(Set(finances.map { $0.category })).sorted()
    }

    var filteredFinances: [FinanceRecord] {
        var result = finances

        // Filter by text
        if !searchText.isEmpty {
            result = result.filter { record in
                return record.description.lowercased().contains(searchText.lowercased()) ||
                       record.category.lowercased().contains(searchText.lowercased()) ||
                       (record.subcategory ?? "").lowercased().contains(searchText.lowercased()) ||
                       (record.eventTitle ?? "").lowercased().contains(searchText.lowercased())
            }
        }

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by event
        if let event = selectedEvent {
            result = result.filter { $0.eventId == event.id }
        }

        return result
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    if userRole == "Admin" || userRole == "Manager" {
                        // Currency Selection
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Currency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)

                            Picker("Currency", selection: $selectedCurrency) {
                                ForEach(currencies, id: \.self) { currency in
                                    Text(currency).tag(currency)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Time period selection
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time Range")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)

                            Picker("Time Range", selection: $selectedTimeRange) {
                                Text("Week").tag(TimeRange.week)
                                Text("Month").tag(TimeRange.month)
                                Text("Year").tag(TimeRange.year)
                                Text("All").tag(TimeRange.all)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal)

                        // Financial summary
                        VStack(spacing: 0) {
                            HStack {
                                Text("Financial Summary")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 10)

                            FinanceSummaryView(totalIncome: totalIncome, totalExpenses: totalExpenses, currency: selectedCurrency)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 5)
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 5)

                        // Income/Expenses chart
                        VStack(spacing: 0) {
                            HStack {
                                Text("Financial Activity")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 10)

                            FinanceChartView(finances: finances)
                                .frame(height: 200)
                                .padding(.bottom, 10)
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Search Transactions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)

                                TextField("Search transactions...", text: $searchText)

                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)

                        // Filter by events if there are related events
                        if !events.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Events")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // "All" button
                                        EventFilterChip(
                                            title: "All Events",
                                            isSelected: selectedEvent == nil,
                                            action: { selectedEvent = nil }
                                        )

                                        // Filter by events
                                        ForEach(events.filter { event in
                                            finances.contains { $0.eventId == event.id }
                                        }) { event in
                                            EventFilterChip(
                                                title: event.title,
                                                isSelected: selectedEvent?.id == event.id,
                                                action: {
                                                    selectedEvent = (selectedEvent?.id == event.id) ? nil : event
                                                }
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(.horizontal)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Categories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)

                            CategoryFilterView(selectedCategory: $selectedCategory, categories: allCategories)
                        }
                        .padding(.horizontal)
                        .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Transactions")
                                    .font(.headline)
                                Spacer()
                                Text("\(filteredFinances.count) items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            // Вместо List используем ScrollView с VStack
                            // для большей гибкости дизайна
                            if filteredFinances.isEmpty {
                                VStack {
                                    Text("No transactions found")
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                                .frame(height: 100)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(filteredFinances.indices, id: \.self) { index in
                                        let record = filteredFinances[index]

                                        FinanceRecordRow(record: record)
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemBackground))
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedRecord = record
                                                showingEditTransaction = true
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    if let arrayIndex = finances.firstIndex(where: { $0.id == record.id }) {
                                                        finances.remove(at: arrayIndex)
                                                        // Удаление из Firebase делается при вызове onDelete
                                                        let db = Firestore.firestore()
                                                        db.collection("finances").document(record.id).delete()
                                                        calculateTotals()
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        // Внутри VStack в блоке "else" (где отображаются транзакции)
                                        VStack(spacing: 0) {
                                            // Существующий код с ForEach...
                                            ForEach(filteredFinances.indices, id: \.self) { index in
                                                let record = filteredFinances[index]
                                                
                                                FinanceRecordRow(record: record)
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 8)
                                                    .background(Color(.systemBackground))
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        selectedRecord = record
                                                        showingEditTransaction = true
                                                    }
                                                    .contextMenu {
                                                        Button(role: .destructive) {
                                                            if let arrayIndex = finances.firstIndex(where: { $0.id == record.id }) {
                                                                finances.remove(at: arrayIndex)
                                                                // Удаление из Firebase делается при вызове onDelete
                                                                let db = Firestore.firestore()
                                                                db.collection("finances").document(record.id).delete()
                                                                calculateTotals()
                                                            }
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                                
                                                if index < filteredFinances.count - 1 {
                                                    Divider()
                                                        .padding(.leading)
                                                }
                                            }
                                            
                                            if !filteredFinances.isEmpty && filteredFinances.count >= 20 {
                                                Button(action: {
                                                    if let lastRecord = filteredFinances.last {
                                                        loadMoreFinances(after: lastRecord)
                                                    }
                                                }) {
                                                    HStack {
                                                        Text("Load More")
                                                        Image(systemName: "arrow.down.circle")
                                                    }
                                                    .foregroundColor(.blue)
                                                    .padding()
                                                    .frame(maxWidth: .infinity)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .padding(.horizontal)

                                        if index < filteredFinances.count - 1 {
                                            Divider()
                                                .padding(.leading)
                                        }
                                    }

                                    if !filteredFinances.isEmpty && filteredFinances.count >= 20 {
                                        Button(action: {
                                            if let lastRecord = filteredFinances.last {
                                                loadMoreFinances(after: lastRecord)
                                            }
                                        }) {
                                            Text("Load More")
                                                .foregroundColor(.blue)
                                                .padding()
                                        }
                                    }
                                }
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }

                        VStack(spacing: 15) {
                            HStack(spacing: 15) {
                                Button(action: {
                                    showingAddTransaction = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Transaction")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }

                                Button(action: {
                                    showingMerchandiseSale = true
                                }) {
                                    HStack {
                                        Image(systemName: "tag.fill")
                                        Text("Record Sale")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }

                            HStack(spacing: 15) {
                                NavigationLink(destination: MerchandiseInventoryView()) {
                                    HStack {
                                        Image(systemName: "shippingbox.fill")
                                        Text("Inventory")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.9)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }

                                NavigationLink(destination: MerchandiseSalesReportView()) {
                                    HStack {
                                        Image(systemName: "chart.bar.fill")
                                        Text("Sales Report")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.purple.opacity(0.9)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No Access")
                                .foregroundColor(.red)
                                .font(.title)

                            Text("You need admin or manager permissions to view finances")
                                .font(.callout)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 80)
                    }
                }
            }
            .navigationTitle("Finances")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        fetchFinances()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                fetchUserRole()
                FirestoreService.shared.getGroupDefaultCurrency { currency, _ in
                        if let currency = currency {
                            self.selectedCurrency = currency
                        }
                        fetchFinances()
                        fetchEvents()
                        ensureCurrencyRatesAreUpdated {
                            self.calculateTotals()
                        }
                    }
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
            .sheet(isPresented: $showingMerchandiseSale) {
                MerchandiseSaleView { newRecord in
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
                        // Update record in array
                        if let index = finances.firstIndex(where: { $0.id == updatedRecord.id }) {
                            finances[index] = updatedRecord
                        }
                    }
                }
            }
        }
    }

    func ensureCurrencyRatesAreUpdated(completion: @escaping () -> Void) {
        // Get all unique currencies used in records
        let uniqueCurrencies = Set(finances.map { $0.currency })

        // Add current selected currency if not already included
        var currenciesToUpdate = uniqueCurrencies
        currenciesToUpdate.insert(selectedCurrency)

        // Create a group to track completion of all updates
        let updateGroup = DispatchGroup()

        // Request updates for each currency
        for currency in currenciesToUpdate {
            updateGroup.enter()
            CurrencyConverterService.shared.updateExchangeRates(for: currency) { success in
                updateGroup.leave()
            }
        }

        // Call completion when all updates are finished
        updateGroup.notify(queue: .main) {
            completion()
        }
    }

    func calculateTotals() {
        // Get records filtered by the selected time range
        let filteredRecords = filterRecordsByTimeRange(finances)

        // Reset totals
        var incomesSum = 0.0
        var expensesSum = 0.0

        // Process each record
        for record in filteredRecords {
            // Convert currency if needed
            let amount = convertAmountIfNeeded(
                amount: record.amount,
                fromCurrency: record.currency,
                toCurrency: selectedCurrency
            )

            // Add to the appropriate total
            if record.type == .income {
                incomesSum += amount
            } else {
                expensesSum += amount
            }
        }

        // Update the state variables
        DispatchQueue.main.async {
            self.totalIncome = incomesSum
            self.totalExpenses = expensesSum
        }

        // Update currency rates for next calculation
        updateCurrencyRates()
    }

    // Helper function for currency conversion
    func convertAmountIfNeeded(amount: Double, fromCurrency: String, toCurrency: String) -> Double {
        // Если валюты совпадают, конвертировать не нужно
        if fromCurrency == toCurrency {
            return amount
        }
        
        // Пробуем конвертировать с помощью сервиса
        if let convertedAmount = CurrencyConverterService.shared.convert(
            amount: amount,
            from: fromCurrency,
            to: toCurrency
        ) {
            return convertedAmount
        } else {
            // Если сервис не смог конвертировать, используем примерные курсы
            print("Warning: Using approximate exchange rates for \(fromCurrency) to \(toCurrency)")
            return amount * getApproximateRate(from: fromCurrency, to: toCurrency)
        }
    }

    // Returns approximate exchange rate
    private func getApproximateRate(from sourceCurrency: String, to targetCurrency: String) -> Double {
        // Add basic rates for most common currencies
        // This is a fallback if API is unavailable
        let approximateRates: [String: [String: Double]] = [
            "USD": ["EUR": 0.92, "UAH": 38.0],
            "EUR": ["USD": 1.09, "UAH": 41.0],
            "UAH": ["USD": 0.026, "EUR": 0.024]
        ]

        return approximateRates[sourceCurrency]?[targetCurrency] ?? 1.0
    }

    // Update exchange rates for all used currencies
    private func updateCurrencyRates() {
        // Get all unique currencies used in records
        let uniqueCurrencies = Set(finances.map { $0.currency })
        
        print("Updating exchange rates for currencies: \(uniqueCurrencies)")
        
        // Update rates for each currency
        for currency in uniqueCurrencies {
            CurrencyConverterService.shared.updateExchangeRates(for: currency) { success in
                if !success {
                    print("Warning: Failed to update exchange rate for \(currency)")
                }
            }
        }
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
        case .quarter:
            let quarterAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            return records.filter { $0.date >= quarterAgo }
        case .custom:
            // For custom date range, return all records for now
            // This could be updated later to use specific date range
            return records
        }
    }

    func formatCurrency(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        switch currency {
        case "USD":
            formatter.locale = Locale(identifier: "en_US")
        case "EUR":
            formatter.locale = Locale(identifier: "de_DE")
        case "UAH":
            formatter.locale = Locale(identifier: "uk_UA")
        default:
            formatter.locale = Locale.current
        }

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }

    func deleteRecord(at offsets: IndexSet) {
        // Get IDs of records to delete
        let recordsToDelete = offsets.map { filteredFinances[$0] }

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
        for record in recordsToDelete {
            if let index = finances.firstIndex(where: { $0.id == record.id }) {
                finances.remove(at: index)
            }
        }
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

    func fetchFinances(limit: Int = 20) {
        // Reset current data
        finances = []
        isLoading = true

        guard let user = Auth.auth().currentUser else {
            print("User not authorized")
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        
        // Get initial batch of finance records
        db.collection("finances")
          .whereField("userId", isEqualTo: user.uid)
          .order(by: "date", descending: true)
          .limit(to: limit)
          .getDocuments { snapshot, error in
            self.isLoading = false
            
            if let error = error {
                print("Error fetching finances: \(error.localizedDescription)")
                return
            }
            
            self.processFinanceDocuments(snapshot?.documents ?? [])
            
            // Calculate totals after data is loaded
            self.calculateTotals()
        }
    }

    // New helper method to process documents
    private func processFinanceDocuments(_ documents: [QueryDocumentSnapshot]) {
        var tempRecords: [FinanceRecord] = []
        
        for document in documents {
            let data = document.data()
            
            // Extract required fields with proper type checking
            guard let typeString = data["type"] as? String,
                  let amount = data["amount"] as? Double,
                  let description = data["description"] as? String,
                  let category = data["category"] as? String else {
                print("Document missing required fields: \(document.documentID)")
                continue
            }
            
            // Currency (with default value)
            let currency = data["currency"] as? String ?? "USD"
            
            // Date (with default value)
            let date: Date
            if let timestamp = data["date"] as? Timestamp {
                date = timestamp.dateValue()
            } else {
                date = Date()
            }
            
            // Transaction type
            let type: FinanceType = typeString == "income" ? .income : .expense
            
            // Optional fields
            let receiptImageURL = data["receiptImageURL"] as? String
            let eventId = data["eventId"] as? String
            let eventTitle = data["eventTitle"] as? String
            let subcategory = data["subcategory"] as? String
            let tags = data["tags"] as? [String]
            
            // Create record
            let record = FinanceRecord(
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
            
            tempRecords.append(record)
        }
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.finances = tempRecords
        }
    }

    // Add a method to load more data
    func loadMoreFinances(after lastRecord: FinanceRecord, limit: Int = 20) {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        
        db.collection("finances")
          .whereField("userId", isEqualTo: user.uid)
          .order(by: "date", descending: true)
          .start(after: [Timestamp(date: lastRecord.date)])
          .limit(to: limit)
          .getDocuments { snapshot, error in
            if let error = error {
                print("Error loading more finances: \(error.localizedDescription)")
                return
            }
            
            let newRecords = self.processFinanceDocumentsAndReturn(snapshot?.documents ?? [])
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.finances.append(contentsOf: newRecords)
                self.calculateTotals()
            }
        }
    }

    // Helper to process documents and return records without updating state
    private func processFinanceDocumentsAndReturn(_ documents: [QueryDocumentSnapshot]) -> [FinanceRecord] {
        var records: [FinanceRecord] = []
        
        // [Тот же код обработки документов, что и в processFinanceDocuments, но с возвратом массива]
        // ...
        
        return records
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
enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    case custom = "Custom"
    case all = "All"

    var id: String { rawValue }
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
        HStack(alignment: .center, spacing: 0) {
            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text(formatCurrency(amount: totalIncome, currency: currency))
                        .foregroundColor(.green)
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text("Income")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text(formatCurrency(amount: totalExpenses, currency: currency))
                        .foregroundColor(.red)
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text("Expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text(formatCurrency(amount: profit, currency: currency))
                        .foregroundColor(profit >= 0 ? .green : .red)
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text("Profit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
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
        VStack(spacing: 15) {
            // Bars
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(chartData, id: \.date) { dataPoint in
                    VStack(spacing: 4) {
                        VStack(spacing: 2) {
                            // Income bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.green.opacity(0.6), Color.green]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 14, height: max(scaledHeight(dataPoint.income), 1))

                            // Expense bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.red.opacity(0.6), Color.red]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 14, height: max(scaledHeight(dataPoint.expense), 1))
                        }

                        Text(formatDate(dataPoint.date))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 150)
            .padding(.horizontal)
            .padding(.top, 10)

            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text("Expense")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // Helper for scaling bar heights
    func scaledHeight(_ value: Double) -> CGFloat {
        let maxValue = chartData.flatMap { [$0.income, $0.expense] }.max() ?? 1
        // Проверяем, чтобы maxValue не был 0 или очень близким к 0
        let safeMaxValue = max(maxValue, 0.0001) // Используем минимальное значение для защиты от деления на 0
        let scale = 150.0 / safeMaxValue
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
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) {
                            Text($0).tag($0)
                        }
                    }

                    TextField("Description", text: $description)

                    Picker("Category", selection: $category) {
                        if transactionType == .income {
                            ForEach(incomeCategories, id: \.self) {
                                Text($0).tag($0)
                            }
                        } else {
                            ForEach(expenseCategories, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                    }

                    if category == "Merchandise" {
                        Picker("Subcategory", selection: $subcategory) {
                            Text("None").tag("")
                            ForEach(merchandiseSubcategories, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section(header: Text("Receipt")) {
                    Button(action: { showImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera")
                                .foregroundColor(.blue)
                            Text(receiptImage == nil ? "Add Receipt" : "Change Receipt")
                                .foregroundColor(.blue)
                        }
                    }

                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: {
                        saveTransaction()
                    }) {
                        HStack {
                            Spacer()
                            if isUploading {
                                ProgressView()
                                    .padding(.trailing, 10)
                            }
                            Text("Save Transaction")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isUploading || !isFormValid)
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
                category = ""
                subcategory = ""
            }
        }
    }

    private var isFormValid: Bool {
        guard !amount.isEmpty,
              let _ = Double(amount),
              !description.isEmpty,
              !category.isEmpty else {
            return false
        }
        return true
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else {
            errorMessage = "Invalid amount"
            return
        }

        isUploading = true
        errorMessage = nil

        if let image = receiptImage {
            ImageUploadService.uploadImage(image) { result in
                switch result {
                case .success(let url):
                    createRecord(receiptURL: url)
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.errorMessage = "Upload error: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            createRecord(receiptURL: nil)
        }
    }

    private func createRecord(receiptURL: String?) {
        let newRecord = FinanceRecord(
            id: UUID().uuidString,
            type: transactionType,
            amount: Double(amount)!,
            currency: currency,
            description: description,
            category: category,
            date: date,
            receiptImageURL: receiptURL,
            eventId: nil,
            eventTitle: nil,
            subcategory: category == "Merchandise" ? subcategory : nil,
            tags: nil
        )

        onAdd(newRecord)

        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}
