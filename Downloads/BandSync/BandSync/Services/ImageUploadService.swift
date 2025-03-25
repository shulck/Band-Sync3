import UIKit
import FirebaseStorage

class ImageUploadService {
    enum ImageUploadError: Error {
        case imageCompressionFailed
        case uploadFailed(Error)
        case urlRetrievalFailed
        case unknown
        
        var localizedDescription: String {
            switch self {
            case .imageCompressionFailed:
                return "Не удалось сжать изображение"
            case .uploadFailed(let error):
                return "Ошибка загрузки: \(error.localizedDescription)"
            case .urlRetrievalFailed:
                return "Не удалось получить URL загруженного изображения"
            case .unknown:
                return "Неизвестная ошибка при загрузке изображения"
            }
        }
    }
    
    static func uploadImage(_ image: UIImage, folder: String = "receipts", completion: @escaping (Result<String, ImageUploadError>) -> Void) {
        // Проверяем, что изображение успешно преобразовано в данные
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            completion(.failure(.imageCompressionFailed))
            return
        }
        
        // Создаем уникальное имя файла
        let imageName = UUID().uuidString
        let storageRef = Storage.storage().reference().child("\(folder)/\(imageName).jpg")
        
        // Метаданные для изображения
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Загружаем изображение
        let uploadTask = storageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(.uploadFailed(error)))
                return
            }
            
            // Получаем URL загруженного изображения
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(.uploadFailed(error)))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(.urlRetrievalFailed))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
        
        // Добавляем обработчик ошибок
        uploadTask.observe(.failure) { snapshot in
            if let error = snapshot.error {
                completion(.failure(.uploadFailed(error)))
            }
        }
    }
    
    // Асинхронная версия метода загрузки
    static func uploadImageAsync(_ image: UIImage, folder: String = "receipts") async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            uploadImage(image, folder: folder) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Метод для удаления изображения по URL
    static func deleteImage(url: String, completion: @escaping (Bool) -> Void) {
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let imageURL = URL(string: encodedURL),
              let imagePath = imageURL.path.components(separatedBy: ".com/o/").last?.removingPercentEncoding else {
            completion(false)
            return
        }
        
        // Создаем ссылку на файл
        let storageRef = Storage.storage().reference().child(imagePath)
        
        // Удаляем файл
        storageRef.delete { error in
            if let error = error {
                print("Error deleting image: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
