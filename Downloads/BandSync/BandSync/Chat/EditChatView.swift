import SwiftUI
import FirebaseFirestore

struct EditChatView: View {
    // Закрытие экрана
    @Environment(\.presentationMode) var presentationMode

    // Основные параметры
    let chatId: String
    @Binding var chatName: String
    let onSave: (Bool) -> Void

    // Локальное состояние
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorText = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)

                VStack(spacing: 24) {
                    // Заголовок группы
                    VStack(spacing: 10) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .padding()
                            .background(Circle().fill(Color.blue.opacity(0.1)))

                        Text("Изменение названия чата")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Введите новое название для группового чата")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Поле ввода
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Название чата:")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        TextField("Введите название чата", text: $inputText)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                            .autocapitalization(.words)
                    }
                    .padding(.horizontal)

                    // Сообщение об ошибке
                    if !errorText.isEmpty {
                        Text(errorText)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.red)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Кнопки
                    VStack(spacing: 16) {
                        Button(action: {
                            saveChanges()
                        }) {
                            ZStack {
                                Rectangle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(height: 54)
                                    .cornerRadius(12)

                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Сохранить")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Отмена")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear {
                // Устанавливаем начальное значение
                inputText = chatName
            }
        }
    }

    private func saveChanges() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Проверка на пустой текст
        if trimmedText.isEmpty {
            return
        }

        // Если имя не изменилось
        if trimmedText == chatName {
            presentationMode.wrappedValue.dismiss()
            return
        }

        // Начинаем сохранение
        isLoading = true
        errorText = ""

        // Сохраняем копию для безопасного использования в замыкании
        let newName = trimmedText
        let saveCallback = onSave

        // Обновляем в базе данных
        let db = Firestore.firestore()
        db.collection("chatRooms").document(chatId).updateData([
            "name": newName
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    // Показываем ошибку
                    isLoading = false
                    errorText = "Ошибка: \(error.localizedDescription)"
                } else {
                    // Успешное сохранение
                    chatName = newName

                    // Закрываем представление
                    presentationMode.wrappedValue.dismiss()

                    // Вызываем callback с задержкой
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        saveCallback(true)
                    }
                }
            }
        }
    }
}
