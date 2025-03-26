import SwiftUI
import FirebaseFirestore

struct ParticipantsView: View {
    let participants: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var userNames: [String: String] = [:]

    var body: some View {
        NavigationView {
            List {
                ForEach(participants, id: \.self) { participantId in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)

                        Text(userNames[participantId] ?? "Загрузка...")
                    }
                }
            }
            .navigationTitle("Участники")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
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
