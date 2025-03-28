import SwiftUI
import FirebaseFirestore

struct ParticipantsView: View {
    let participants: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var userNames: [String: String] = [:]

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)

                List {
                    Section(header: Text("Всего участников: \(participants.count)")
                        .font(.subheadline)
                        .foregroundColor(.gray)) {

                        ForEach(participants, id: \.self) { participantId in
                            HStack(spacing: 14) {
                                // Аватар участника
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [.blue.opacity(0.7), .blue]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
                                        .frame(width: 40, height: 40)

                                    // Инициалы участника
                                    if let name = userNames[participantId], !name.isEmpty {
                                        Text(String(name.prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16))
                                    }
                                }
                                .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)

                                // Имя участника
                                VStack(alignment: .leading, spacing: 4) {
                                    if let name = userNames[participantId] {
                                        Text(name)
                                            .font(.system(size: 16, weight: .medium))
                                    } else {
                                        Text("Загрузка...")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.gray)
                                            .redacted(reason: .placeholder)
                                    }

                                    // Можно добавить дополнительные данные о пользователе здесь
                                    Text("Участник")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Участники чата")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
            )
            .onAppear {
                loadUserNames()
            }
        }
    }

    private func loadUserNames() {
        let db = Firestore.firestore()

        for participantId in participants {
            db.collection("users").document(participantId).getDocument { (snapshot: DocumentSnapshot?, error: Error?) in
                if let error = error {
                    print("Error loading user data: \(error.localizedDescription)")
                    return
                }

                // Проверяем разные поля, где может храниться имя
                if let data = snapshot?.data() {
                    // Пробуем найти имя в различных полях
                    if let name = data["name"] as? String, !name.isEmpty {
                        self.userNames[participantId] = name
                    } else if let name = data["displayName"] as? String, !name.isEmpty {
                        self.userNames[participantId] = name
                    } else if let firstName = data["firstName"] as? String,
                              let lastName = data["lastName"] as? String,
                              !firstName.isEmpty {
                        if lastName.isEmpty {
                            self.userNames[participantId] = firstName
                        } else {
                            self.userNames[participantId] = "\(firstName) \(lastName)"
                        }
                    } else if let email = data["email"] as? String {
                        // Если имя не найдено, создаем имя из email
                        let username = email.components(separatedBy: "@").first ?? email
                        let formattedName = username
                            .replacingOccurrences(of: ".", with: " ")
                            .split(separator: " ")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                            .joined(separator: " ")

                        self.userNames[participantId] = formattedName
                    } else {
                        // Если совсем ничего не найдено
                        self.userNames[participantId] = "User \(participantId.prefix(5))"
                    }
                } else {
                    // Если документ не найден
                    self.userNames[participantId] = "User \(participantId.prefix(5))"
                }
            }
        }
    }
}
