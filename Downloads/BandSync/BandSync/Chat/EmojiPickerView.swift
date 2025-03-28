import SwiftUI

struct EmojiPickerView: View {
    var onEmojiSelected: (String) -> Void

    // Категории эмодзи - расширенная версия
    private let emojiCategories: [String: [String]] = [
        "Часто": ["👍", "👏", "🙌", "🤝", "👀", "👋", "🙂", "😊", "😁", "😄", "😎", "🤔", "🧐", "⏰", "📝", "✅", "❌", "‼️", "❓", "🔥"],
        "Эмоции": ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥲", "☺️", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😮‍💨", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥"],
        "Жесты": ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁", "👅", "👄"],
        "Символы": ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "🆔", "⚛️"],
        "Музыка": ["🎵", "🎶", "🎹", "🪘", "🥁", "🎺", "🎸", "🪕", "🎻", "🎤", "🎧", "🎼", "🎭", "🎬", "🎮", "🎨", "🎯", "🎱", "🎰", "🎲", "🧩", "🪄", "🎪", "🎟", "🎫", "🎠", "🎡", "🎢"],
        "Еда": ["🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶", "🫑", "🥕", "🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕", "🫓", "🥪"]
    ]

    @State private var selectedCategory = "Часто"

    var body: some View {
        VStack(spacing: 8) {
            // Линия-индикатор, что панель можно скрыть
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 4)

            // Категории эмодзи
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(emojiCategories.keys), id: \.self) { category in
                        Text(category)
                            .font(.system(size: 14, weight: selectedCategory == category ? .semibold : .regular))
                            .foregroundColor(selectedCategory == category ? .blue : .gray)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(selectedCategory == category ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(14)
                            .onTapGesture {
                                withAnimation {
                                    selectedCategory = category
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Сетка эмодзи
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                    ForEach(emojiCategories[selectedCategory] ?? [], id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 24))
                            .padding(6)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEmojiSelected(emoji)
                                // Добавляем тактильный отклик
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .animation(.easeInOut, value: selectedCategory)
        }
        .background(
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.bottom)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }
}
