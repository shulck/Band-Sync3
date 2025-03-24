import UIKit
import FirebaseStorage

class ImageUploadService {
    static func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }
        
        let imageName = UUID().uuidString
        let storageRef = Storage.storage().reference().child("receipts/\(imageName).jpg")
        
        storageRef.putData(data) { _, error in
            if error == nil {
                storageRef.downloadURL { url, _ in
                    completion(url?.absoluteString)
                }
            } else {
                completion(nil)
            }
        }
    }
}
