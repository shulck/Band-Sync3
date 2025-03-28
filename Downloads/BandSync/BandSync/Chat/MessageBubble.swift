import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer()
            } else {
                // Аватар для сообщений других пользователей
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.senderName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                
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
                                Color(.systemGray5)
                        )
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(18)
                        .contextMenu {
                            // Контекстное меню только для сообщений текущего пользователя
                            if isFromCurrentUser {
                                Button(action: onEdit ?? {}) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(action: onDelete ?? {}) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    
                    // Индикатор статуса сообщения (только для своих сообщений)
                    if isFromCurrentUser {
                        statusIcon
                            .font(.system(size: 12))
                    }
                }
                
                HStack(spacing: 4) {
                    if message.status == .edited {
                        Text("edited")
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
