import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct EditChatView: View {
    let chatService: ChatService
    let chatId: String
    @Binding var chatName: String
    let onSave: (Bool) -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var newChatName: String = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Название чата")) {
                    TextField("Введите название чата", text: $newChatName)
                }

                Section {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Сохранить")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                    }
                    .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .navigationTitle("Редактировать чат")
            .navigationBarItems(trailing: Button("Отмена") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Безопасная инициализация
                self.newChatName = chatName
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Ошибка"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func saveChanges() {
        let trimmedName = newChatName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Если имя не изменилось, просто закрываем окно
        if trimmedName == chatName {
            presentationMode.wrappedValue.dismiss()
            return
        }

        isSaving = true

        // Создаем локальную копию переменной для безопасного использования в замыкании
        let chatIdCopy = chatId
        let nameCopy = trimmedName

        // Используем простой подход без обратного вызова для начала
        DispatchQueue.main.async {
            chatService.isLoading = true

            // Редактируем напрямую через Firestore, минуя сложную логику
            let db = Firestore.firestore()

            db.collection("chatRooms").document(chatIdCopy)
                .updateData(["name": nameCopy]) { error in
                    DispatchQueue.main.async {
                        chatService.isLoading = false
                        isSaving = false

                        if let error = error {
                            // Обработка ошибки
                            alertMessage = "Ошибка: \(error.localizedDescription)"
                            showAlert = true
                        } else {
                            // Успешное обновление
                            chatName = nameCopy
                            presentationMode.wrappedValue.dismiss()

                            // Уведомляем родительский компонент о успешном обновлении
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onSave(true)
                            }
                        }
                    }
                }
        }
    }
}
