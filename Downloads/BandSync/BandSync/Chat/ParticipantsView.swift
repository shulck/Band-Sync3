import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ParticipantsView: View {
    let participants: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var userNames: [String: String] = [:]
    @State private var userEmails: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    private var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView("Загрузка участников...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text("Ошибка")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            self.isLoading = true
                            self.errorMessage = nil
                            self.loadUserProfiles()
                        }) {
                            Text("Повторить")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        List {
                            Section(header: Text("Всего участников: \(participants.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)) {
                                
                                ForEach(participants, id: \.self) { participantId in
                                    ParticipantRow(
                                        participantId: participantId,
                                        name: userNames[participantId] ?? "Загрузка...",
                                        email: userEmails[participantId] ?? "",
                                        isCurrentUser: participantId == currentUserId
                                    )
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationTitle("Участники чата")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
            )
            .onAppear {
                loadUserProfiles()
            }
        }
    }

    private func loadUserProfiles() {
        isLoading = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()

        // Проходимся по всем участникам и загружаем их профили
        for participantId in participants {
            dispatchGroup.enter()
            db.collection("users").document(participantId).getDocument { (snapshot: DocumentSnapshot?, error: Error?) in
                defer {
                    dispatchGroup.leave()
                }
                
                if let error = error {
                    print("⛔️ Error loading participant \(participantId): \(error.localizedDescription)")
                    // Продолжаем загрузку других участников
                    return
                }

                if let data = snapshot?.data() {
                    // Определяем имя пользователя
                    let userName: String
                    if let name = data["name"] as? String, !name.isEmpty {
                        userName = name
                    } else if let displayName = data["displayName"] as? String, !displayName.isEmpty {
                        userName = displayName
                    } else if let email = data["email"] as? String {
                        // Используем часть email до @ в качестве имени
                        let parts = email.split(separator: "@")
                        if parts.count > 0 {
                            userName = String(parts[0]).capitalized
                        } else {
                            userName = "Пользователь \(participantId.prefix(6))"
                        }
                    } else {
                        userName = "Пользователь \(participantId.prefix(6))"
                    }
                    
                    // Получаем email
                    let email = data["email"] as? String ?? ""
                    
                    // Обновляем состояние
                    DispatchQueue.main.async {
                        self.userNames[participantId] = userName
                        self.userEmails[participantId] = email
                    }
                } else {
                    // Если данные не найдены, устанавливаем стандартное имя
                    DispatchQueue.main.async {
                        self.userNames[participantId] = "Пользователь \(participantId.prefix(6))"
                    }
                }
            }
        }
        
        // После завершения всех запросов
        dispatchGroup.notify(queue: .main) {
            if userNames.isEmpty && !participants.isEmpty {
                errorMessage = "Не удалось загрузить информацию об участниках"
            }
            isLoading = false
        }
    }
}

struct ParticipantRow: View {
    let participantId: String
    let name: String
    let email: String
    let isCurrentUser: Bool
    
    // Функция для генерации стабильного цвета на основе ID пользователя
    private func colorForUser(userId: String) -> LinearGradient {
        // Список пар цветов для градиентов
        let colorPairs: [(Color, Color)] = [
            (.blue, .blue.opacity(0.7)),
            (.green, .green.opacity(0.7)),
            (.orange, .orange.opacity(0.7)),
            (.purple, .purple.opacity(0.7)),
            (.pink, .pink.opacity(0.7)),
            (.red, .red.opacity(0.7)),
            (.yellow, .yellow.opacity(0.6)),
            (.teal, .teal.opacity(0.7)),
            (.indigo, .indigo.opacity(0.7)),
            (.cyan, .cyan.opacity(0.7))
        ]
        
        // Если это текущий пользователь, возвращаем зеленый градиент
        if isCurrentUser {
            return LinearGradient(
                gradient: Gradient(colors: [.green.opacity(0.7), .green]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Для остальных пользователей генерируем цвет по ID
        var hash = 0
        for char in userId {
            hash = ((hash << 5) &- hash) &+ Int(char.asciiValue ?? 0)
        }
        
        let absHash = abs(hash)
        let colorIndex = absHash % colorPairs.count
        let (color1, color2) = colorPairs[colorIndex]
        
        return LinearGradient(
            gradient: Gradient(colors: [color1, color2]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Генерация инициалов пользователя (до 2 букв)
    private func initialsForUser(name: String) -> String {
        let components = name.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if components.isEmpty {
            return "?"
        }
        
        if components.count == 1 {
            // Одно слово - берем первую букву или первые две, если имя длинное
            let name = components[0]
            if name.count > 3 {
                return String(name.prefix(2)).uppercased()
            } else {
                return String(name.prefix(1)).uppercased()
            }
        } else {
            // Два слова - берем первые буквы каждого слова
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Аватар участника
            ZStack {
                Circle()
                    .fill(colorForUser(userId: participantId))
                    .frame(width: 40, height: 40)
                    .shadow(color: isCurrentUser ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)

                // Инициалы участника или иконка для загрузки
                if name == "Загрузка..." {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    Text(initialsForUser(name: name))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            // Информация об участнике
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                    
                    if isCurrentUser {
                        Text("(Вы)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
