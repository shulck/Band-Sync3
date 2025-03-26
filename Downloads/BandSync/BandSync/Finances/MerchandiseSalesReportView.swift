import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MerchandiseSalesReportView: View {
    @State private var isLoading = true
    @State private var salesData: [FinanceRecord] = []
    @State private var merchandiseItems: [MerchandiseItem] = []
    @State private var selectedTimeRange: TimeRange = .month
    @State private var startDate = Date().startOfMonth()
    @State private var endDate = Date().endOfMonth()
    @State private var selectedCurrency = "USD" // Добавляем валюту

    let currencies = ["USD", "EUR", "UAH", "GBP"] // Список валют

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var filteredSales: [FinanceRecord] {
        return salesData.filter { record in
            record.date >= startDate && record.date <= endDate
        }
    }

    var totalSalesAmount: Double {
        return filteredSales.reduce(0) { $0 + $1.amount }
    }

    var salesByCategory: [String: Double] {
        var result: [String: Double] = [:]

        for record in filteredSales {
            if let subcategory = record.subcategory {
                let current = result[subcategory] ?? 0
                result[subcategory] = current + record.amount
            } else {
                let current = result["Other"] ?? 0
                result["Other"] = current + record.amount
            }
        }

        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date range selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Period")
                        .font(.headline)

                    Picker("Time Range", selection: $selectedTimeRange) {
                        Text("This Week").tag(TimeRange.week)
                        Text("This Month").tag(TimeRange.month)
                        Text("This Quarter").tag(TimeRange.quarter)
                        Text("This Year").tag(TimeRange.year)
                        Text("Custom").tag(TimeRange.custom)
                    }
                    .onChange(of: selectedTimeRange) { newValue in
                        updateDateRange()
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if selectedTimeRange == .custom {
                        HStack {
                            DatePicker("From", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()

                            Text("to")

                            DatePicker("To", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    } else {
                        Text("\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // Добавляем выбор валюты
                VStack(alignment: .leading, spacing: 10) {
                    Text("Currency")
                        .font(.headline)

                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                if isLoading {
                    ProgressView("Loading sales data...")
                        .padding()
                } else {
                    // Sales summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sales Summary")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Sales")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(formatCurrency(totalSalesAmount))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("Number of Transactions")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("\(filteredSales.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Sales by category
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sales by Category")
                            .font(.headline)
                            .padding(.horizontal)

                        if salesByCategory.isEmpty {
                            Text("No sales data for this period")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(salesByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                                CategorySalesRow(category: category, amount: amount, total: totalSalesAmount, currency: selectedCurrency)
                            }
                        }
                    }
                    .padding(.vertical)

                    // Recent sales transactions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Transactions")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredSales.isEmpty {
                            Text("No transactions for this period")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(filteredSales.prefix(10)) { sale in
                                SaleTransactionRow(sale: sale, displayCurrency: selectedCurrency)
                            }

                            if filteredSales.count > 10 {
                                Button(action: {
                                    // Action to view all transactions
                                }) {
                                    Text("View All \(filteredSales.count) Transactions")
                                        .foregroundColor(.blue)
                                        .padding()
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Merchandise Sales Report")
            .onAppear {
                fetchSalesData()
            }
        }
    }

    private func updateDateRange() {
        let now = Date()

        switch selectedTimeRange {
        case .week:
            startDate = now.startOfWeek()
            endDate = now.endOfWeek()
        case .month:
            startDate = now.startOfMonth()
            endDate = now.endOfMonth()
        case .quarter:
            startDate = now.startOfQuarter()
            endDate = now.endOfQuarter()
        case .year:
            startDate = now.startOfYear()
            endDate = now.endOfYear()
        case .custom:
            // Keep existing custom dates
            break
        case .all:
            // Use a very old start date
            startDate = Calendar.current.date(byAdding: .year, value: -10, to: now)!
            endDate = now
        }
    }

    private func fetchSalesData() {
        isLoading = true

        let db = Firestore.firestore()

        // Fetch merchandise sales records
        db.collection("finances")
            .whereField("category", isEqualTo: "Merchandise")
            .whereField("type", isEqualTo: "income")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching sales data: \(error.localizedDescription)")
                    isLoading = false
                    return
                }

                salesData = snapshot?.documents.compactMap { document -> FinanceRecord? in
                    let data = document.data()

                    guard let typeString = data["type"] as? String,
                          let amount = data["amount"] as? Double,
                          let currency = data["currency"] as? String,
                          let description = data["description"] as? String,
                          let category = data["category"] as? String,
                          let timestamp = data["date"] as? Timestamp else {
                        return nil
                    }

                    let type: FinanceType = typeString == "income" ? .income : .expense
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
                } ?? []

                // Sort by date, newest first
                salesData.sort { $0.date > $1.date }

                // Fetch merchandise items in parallel
                db.collection("merchandise").getDocuments { snapshot, error in
                    isLoading = false

                    if let error = error {
                        print("Error fetching merchandise items: \(error.localizedDescription)")
                        return
                    }

                    merchandiseItems = snapshot?.documents.compactMap { document in
                        return MerchandiseItem(document: document)
                    } ?? []
                }
            }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency // Используем выбранную валюту

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(selectedCurrency)"
    }
}

struct CategorySalesRow: View {
    let category: String
    let amount: Double
    let total: Double
    let currency: String // Добавляем параметр валюты

    var percentage: Double {
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category)
                    .font(.subheadline)

                Spacer()

                Text(formatCurrency(amount))
                    .font(.subheadline)
            }

            HStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .foregroundColor(Color(.systemGray5))
                            .cornerRadius(4)

                        Rectangle()
                            .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}

struct SaleTransactionRow: View {
    let sale: FinanceRecord
    let displayCurrency: String? // Параметр для отображения валюты

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sale.description)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack {
                    Text(formatDate(sale.date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let eventTitle = sale.eventTitle {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(eventTitle)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Text(formatCurrency(sale.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = displayCurrency ?? sale.currency

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(sale.currency)"
    }
}

// Date extensions for time ranges
extension Date {
    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }

    func endOfDay() -> Date {
        var components = DateComponents()
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay())!
    }

    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }

    func endOfWeek() -> Date {
        var components = DateComponents()
        components.day = 7
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek())!
    }

    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }

    func endOfMonth() -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth())!
    }

    func startOfQuarter() -> Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let quarter = ((month - 1) / 3) * 3 + 1
        var components = calendar.dateComponents([.year], from: self)
        components.month = quarter
        components.day = 1
        return calendar.date(from: components)!
    }

    func endOfQuarter() -> Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let quarter = ((month - 1) / 3) * 3 + 3
        var components = calendar.dateComponents([.year], from: self)
        components.month = quarter + 1
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfQuarter())!
    }

    func startOfYear() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components)!
    }

    func endOfYear() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: self)
        components.year = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfYear())!
    }
}
