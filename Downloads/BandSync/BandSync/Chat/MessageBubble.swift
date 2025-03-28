import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReply: (() -> Void)?
    let onTapReply: ((String) -> Void)?
    
    // Функция для генерации стабильного цвета на основе ID пользователя
    private func colorForUser(userId: String) -> Color {
        // Список ярких цветов для аватаров
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink,
            .red, .yellow, .teal, .indigo, .cyan
        ]
        
        // Используем хеш ID пользователя для выбора цвета
        var hash = 0
        for char in userId {
            hash = ((hash << 5) &- hash) &+ Int(char.asciiValue ?? 0)
        }
        
        // Приводим хеш к положительному числу и выбираем индекс
        let absHash = abs(hash)
        let colorIndex = absHash % colors.count
        
        return colors[colorIndex]
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
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer()
            } else {
                // Аватар для сообщений других пользователей
                AvatarView(name: message.senderName, userId: message.senderId)
                    .frame(width: 36, height: 36)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                
                // Основное содержимое сообщения
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Блок с ответом, если есть
                    if let reply = message.replyTo {
                        ReplyView(
                            replyText: reply.text,
                            senderName: reply.senderName,
                            senderId: reply.senderId,
                            onTap: {
                                // Обработчик нажатия на цитируемое сообщение
                                if let onTapReply = onTapReply {
                                    onTapReply(reply.messageId)
                                }
                            }
                        )
                    }
                    
                    // Текст сообщения
                    HStack(alignment: .bottom, spacing: 4) {
                        if message.status == .failed {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                        }
                        
                        Text(message.text)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                isFromCurrentUser ?
                                    Color.blue :
                                    Color(.systemGray6)
                            )
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .cornerRadius(18)
                        
                        // Индикатор статуса сообщения (только для своих сообщений)
                        if isFromCurrentUser {
                            statusIcon
                                .font(.system(size: 12))
                        }
                    }
                }
                .contextMenu {
                    // Опция ответа для всех сообщений
                    if let onReply = onReply {
                        Button(action: onReply) {
                            Label("Ответить", systemImage: "arrowshape.turn.up.left")
                        }
                    }
                    
                    // Контекстное меню только для сообщений текущего пользователя
                    if isFromCurrentUser {
                        if let onEdit = onEdit {
                            Button(action: onEdit) {
                                Label("Редактировать", systemImage: "pencil")
                            }
                        }
                        
                        if let onDelete = onDelete {
                            Button(action: onDelete) {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    if message.status == .edited {
                        Text("изменено")
                            .font(.system(size: 10))
                            .italic()
                            .foregroundColor(.gray)
                    }
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
    
    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(.gray)
            case .delivered:
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
            case .edited:
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Вынесенная отдельно структура для аватара
struct AvatarView: View {
    let name: String
    let userId: String
    
    // Функция для генерации стабильного цвета на основе ID пользователя
    private func colorForUser(userId: String) -> Color {
        // Список ярких цветов для аватаров
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink,
            .red, .yellow, .teal, .indigo, .cyan
        ]
        
        // Используем хеш ID пользователя для выбора цвета
        var hash = 0
        for char in userId {
            hash = ((hash << 5) &- hash) &+ Int(char.asciiValue ?? 0)
        }
        
        // Приводим хеш к положительному числу и выбираем индекс
        let absHash = abs(hash)
        let colorIndex = absHash % colors.count
        
        return colors[colorIndex]
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
        ZStack {
            Circle()
                .fill(colorForUser(userId: userId))
                .shadow(radius: 1)
                
            Text(initialsForUser(name: name))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// Компонент для отображения цитируемого сообщения
struct ReplyView: View {
    let replyText: String
    let senderName: String
    let senderId: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Имя отправителя цитируемого сообщения
                    HStack(spacing: 4) {
                        AvatarView(name: senderName, userId: senderId)
                            .frame(width: 18, height: 18)
                        
                        Text(senderName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    // Текст цитируемого сообщения
                    Text(replyText)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(8)
            .frame(maxWidth: 240)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
