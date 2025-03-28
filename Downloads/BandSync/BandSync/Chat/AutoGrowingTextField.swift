import SwiftUI
import UIKit

struct AutoGrowingTextField: UIViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 32
    var maxHeight: CGFloat = 100

    // Создадим привязку для отслеживания высоты
    @Binding var height: CGFloat

    // Инициализатор с опциональной привязкой высоты
    init(text: Binding<String>, minHeight: CGFloat = 32, maxHeight: CGFloat = 100, height: Binding<CGFloat>? = nil) {
        self._text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self._height = height ?? .constant(minHeight)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Начальная высота
        textView.frame.size.height = minHeight

        // Важно для правильного обновления высоты
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        textView.isScrollEnabled = false

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Обновляем текст только если он изменился извне
        if uiView.text != text {
            uiView.text = text
        }

        // Необходимо для корректного расчета высоты
        DispatchQueue.main.async {
            updateHeight(uiView)
        }
    }

    private func updateHeight(_ uiView: UITextView) {
        // Сохраняем текущую ширину
        let fixedWidth = uiView.frame.size.width
        
        // Рассчитываем новый размер
        let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        
        // Ограничиваем высоту
        let boundedHeight = min(max(newSize.height, minHeight), maxHeight)
        
        // Обновляем привязку высоты и frame только если высота изменилась
        if height != boundedHeight {
            height = boundedHeight
            uiView.frame.size.height = boundedHeight
        }
        
        // Включаем прокрутку только когда текст слишком большой
        uiView.isScrollEnabled = newSize.height > maxHeight
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoGrowingTextField

        init(_ parent: AutoGrowingTextField) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text

            // Обновляем высоту при изменении текста
            parent.updateHeight(textView)
        }
    }
}
