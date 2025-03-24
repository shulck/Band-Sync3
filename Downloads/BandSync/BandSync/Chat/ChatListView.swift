import SwiftUI
import FirebaseAuth

struct ChatListView: View {
    @StateObject private var chatService = ChatService()
    @State private var showingNewChatView = false
    @State private var searchText = ""

    var filteredChatRooms: [ChatRoom] {
        if searchText.isEmpty {
            return chatService.chatRooms
        } else {
            return chatService.chatRooms.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredChatRooms) { chatRoom in
                    NavigationLink(destination: ChatView(chatRoom: chatRoom)) {
                        HStack {
                            // Аватар чата (иконка группы или индивидуальная)
                            Image(systemName: chatRoom.isGroupChat ? "person.3.fill" : "person.fill")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.blue))

                            VStack(alignment: .leading) {
                                Text(chatRoom.name)
                                    .font(.headline)

                                if let lastMessage = chatRoom.lastMessage {
                                    Text(lastMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if let date = chatRoom.lastMessageDate {
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Chats")
            .searchable(text: $searchText, prompt: "Search chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewChatView = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewChatView) {
                NewChatView(chatService: chatService)
            }
            .onAppear {
                chatService.fetchChatRooms()
            }
            .onDisappear {
                chatService.stopListening()
            }
        }
    }

    // Форматирование даты для отображения
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: date)
        }
    }
}
