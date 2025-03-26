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
        // Самый базовый интерфейс для избежания проблем с белым экраном
        ZStack {
            // Фон
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            // Основной контент
            VStack(spacing: 30) {
                // Заголовок
                Text("Редактирование чата")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                
                // Поле ввода
                VStack(alignment: .leading, spacing: 10) {
                    Text("Название:")
                        .font(.headline)
                    
                    TextField("Введите название чата", text: $inputText)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Сообщение об ошибке
                if !errorText.isEmpty {
                    Text(errorText)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Кнопки
                VStack(spacing: 15) {
                    Button(action: {
                        saveChanges()
                    }) {
                        ZStack {
                            Rectangle()
                                .foregroundColor(.blue)
                                .frame(height: 50)
                                .cornerRadius(10)
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Сохранить")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Отмена")
                            .foregroundColor(.red)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Устанавливаем начальное значение
            inputText = chatName
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
