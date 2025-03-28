import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EventFinancesView: View {
    var event: Event
    @State private var finances: [FinanceRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showingAddTransactionSheet = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView(LocalizedStringKey("loading_data"))
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)

                    Text(LocalizedStringKey("error"))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    Button(LocalizedStringKey("try_again")) {
                        errorMessage = nil
                        fetchEventFinances()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding()
            } else if finances.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            .linearGradient(colors: [.blue, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color.blue.opacity(0.2), radius: 5, x: 0, y: 3)

                    Text("Нет финансовых записей для этого события")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Добавьте доходы или расходы, связанные с этим событием")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: 300)

                    Button(action: {
                        showingAddTransactionSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Добавить транзакцию")
                        }
                        .padding()
                        .frame(minWidth: 200)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                )
                .padding()
            } else {
                VStack {
                    // Финансовая сводка
                    FinancialSummaryCard(finances: finances)
                        .padding()

                    // Список транзакций
                    List {
                        ForEach(finances) { record in
                            FinanceRecordRow(record: record)
                        }
                    }

                    Button(action: {
                        showingAddTransactionSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить транзакцию")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(gradient:
                                Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("event_finances"))
        .onAppear {
            fetchEventFinances()
        }
        .sheet(isPresented: $showingAddTransactionSheet) {
            EventTransactionView(event: event) { newRecord in
                finances.append(newRecord)
                isLoading = false
            }
        }
    }

    private func fetchEventFinances() {
        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()
        db.collection("finances")
            .whereField("eventId", isEqualTo: event.id)
            .getDocuments { snapshot, error in
                isLoading = false

                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                finances = snapshot?.documents.compactMap { document -> FinanceRecord? in
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
            }
    }
}

struct FinancialSummaryCard: View {
    var finances: [FinanceRecord]

    var totalIncome: Double {
        finances.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        finances.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var profit: Double {
        totalIncome - totalExpenses
    }

    var mainCurrency: String {
        // Определяем основную валюту по большинству записей
        let currencies = finances.map { $0.currency }
        return currencies.max { a, b in
            currencies.filter { $0 == a }.count < currencies.filter { $0 == b }.count
        } ?? "USD"
    }

    var body: some View {
        VStack(spacing: 15) {
            Text("Финансовая сводка")
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.primary)

            HStack(spacing: 20) {
                // Доходы
                VStack(spacing: 6) {
                    Text("Доходы")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatMoney(totalIncome, currency: mainCurrency))
                        .foregroundColor(.green)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)

                // Расходы
                VStack(spacing: 6) {
                    Text("Расходы")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatMoney(totalExpenses, currency: mainCurrency))
                        .foregroundColor(.red)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)

                // Прибыль
                VStack(spacing: 6) {
                    Text("Прибыль")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatMoney(profit, currency: mainCurrency))
                        .foregroundColor(profit >= 0 ? .green : .red)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(profit >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    Color(.systemBackground)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private func formatMoney(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}

struct EventTransactionView: View {
    @Environment(\.presentationMode) var presentationMode
    var event: Event
    var onAdd: (FinanceRecord) -> Void

    @State private var transactionType: FinanceType = .income
    @State private var amount = ""
    @State private var description = ""
    @State private var category = ""
    @State private var currency = "USD"
    @State private var showImagePicker = false
    @State private var receiptImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var subcategory = ""

    let currencies = ["USD", "EUR", "UAH"]
    let incomeCategories = ["Gig", "Merchandise", "Royalties", "Sponsorship", "Other"]
    let expenseCategories = ["Logistics", "Accommodation", "Food", "Equipment", "Promotion", "Fees", "Other"]
    let merchandiseSubcategories = ["T-Shirts", "Hoodies", "Hats", "Pins/Stickers", "CDs/Vinyl", "Posters", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Тип транзакции")) {
                    Picker("Тип", selection: $transactionType) {
                        Text("Доход").tag(FinanceType.income)
                        Text("Расход").tag(FinanceType.expense)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Информация о событии")) {
                    HStack {
                        Image(systemName: event.icon == "📅" ? "calendar" : "music.note")
                        Text(event.title)
                            .font(.headline)
                    }

                    HStack {
                        Text("Дата:")
                        Spacer()
                        Text(formattedDate(event.date))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Место:")
                        Spacer()
                        Text(event.location)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Детали транзакции")) {
                    TextField("Сумма", text: $amount)
                        .keyboardType(.decimalPad)

                    Picker("Валюта", selection: $currency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }

                    TextField("Описание", text: $description)

                    Picker("Категория", selection: $category) {
                        ForEach(transactionType == .income ? incomeCategories : expenseCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }

                    if category == "Merchandise" {
                        Picker("Подкатегория", selection: $subcategory) {
                            Text("None").tag("")
                            ForEach(merchandiseSubcategories, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                    }
                }

                Section(header: Text("Чек/Квитанция")) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Text(receiptImage == nil ? "Добавить изображение чека" : "Изменить изображение чека")
                            Spacer()
                            if receiptImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if let receiptImage = receiptImage {
                        Image(uiImage: receiptImage)
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
                            Text("Сохранить")
                        }
                    }
                    .disabled(isUploading || !isFormValid)
                }
            }
            .navigationTitle("Новая транзакция")
            .navigationBarItems(trailing: Button("Отмена") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $receiptImage)
            }
        }
    }

    private var isFormValid: Bool {
        let validationResult = FinanceValidator.validateFinanceRecord(
            amount: amount,
            currency: currency,
            description: description,
            category: category,
            type: transactionType
        )

        if !validationResult.isValid && errorMessage == nil {
            errorMessage = validationResult.error
        }

        return validationResult.isValid
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else {
            errorMessage = "Пожалуйста, введите корректную сумму"
            return
        }

        isUploading = true
        errorMessage = nil

        if let image = receiptImage {
            ImageUploadService.uploadImage(image) { result in
                switch result {
                case .success(let url):
                    self.createRecord(receiptURL: url)
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.errorMessage = "Ошибка загрузки чека: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            createRecord(receiptURL: nil)
        }
    }

    private func createRecord(receiptURL: String?) {
        guard let amountValue = Double(amount) else {
            isUploading = false
            return
        }

        let db = Firestore.firestore()

        // Создаем новую запись
        let record = FinanceRecord(
            id: UUID().uuidString,
            type: transactionType,
            amount: amountValue,
            currency: currency,
            description: description,
            category: category,
            date: Date(),
            receiptImageURL: receiptURL,
            eventId: event.id,
            eventTitle: event.title,
            subcategory: category == "Merchandise" && !subcategory.isEmpty ? subcategory : nil,
            tags: nil
        )

        // Сохраняем в Firebase
        var data: [String: Any] = [
            "type": transactionType == .income ? "income" : "expense",
            "amount": amountValue,
            "currency": currency,
            "description": description,
            "category": category,
            "date": Timestamp(date: Date()),
            "eventId": event.id,
            "eventTitle": event.title
        ]

        if let receiptImageURL = receiptURL {
            data["receiptImageURL"] = receiptImageURL
        }

        if category == "Merchandise" && !subcategory.isEmpty {
            data["subcategory"] = subcategory
        }

        if let user = Auth.auth().currentUser {
            data["userId"] = user.uid
            data["createdBy"] = user.displayName ?? user.email ?? "Unknown"
        }

        db.collection("finances").document(record.id).setData(data) { error in
            DispatchQueue.main.async {
                self.isUploading = false

                if let error = error {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                } else {
                    onAdd(record)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
