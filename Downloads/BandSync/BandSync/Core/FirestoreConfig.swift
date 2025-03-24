import Foundation
import FirebaseFirestore
import FirebaseAuth

// This class serves for centralized access to Firestore
// and standardization of basic database operations
class FirestoreService {
    // Shared instance for use throughout the application
    static let shared = FirestoreService()

    // Firestore instance
    private let db = Firestore.firestore()

    private init() {
        // Firestore configuration is performed automatically by Firebase SDK
        // Don't use deprecated properties
        print("🔥 Firestore initialized successfully")
    }

    // MARK: - Common methods

    // Get current user ID
    func currentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }

    // Get current user's group information
    func getCurrentUserGroup(completion: @escaping (String?, String?, Error?) -> Void) {
        guard let userId = currentUserId() else {
            completion(nil, nil, NSError(domain: "FirestoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }

        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(nil, nil, error)
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                completion(nil, nil, NSError(domain: "FirestoreService", code: 2, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }

            guard let groupId = data["groupId"] as? String else {
                completion(nil, nil, NSError(domain: "FirestoreService", code: 3, userInfo: [NSLocalizedDescriptionKey: "User has no group"]))
                return
            }

            // Get group name
            self.db.collection("groups").document(groupId).getDocument { groupDoc, error in
                if let error = error {
                    completion(groupId, nil, error)
                    return
                }

                guard let groupDoc = groupDoc, let groupData = groupDoc.data() else {
                    completion(groupId, nil, NSError(domain: "FirestoreService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Group document not found"]))
                    return
                }

                let groupName = groupData["name"] as? String ?? "Unknown Group"
                completion(groupId, groupName, nil)
            }
        }
    }

    // MARK: - Helper methods

    // Generate unique group code
    func generateGroupCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Without similar characters
        return String((0..<6).map{ _ in letters.randomElement()! })
    }

    // Check if group code exists
    func checkGroupCode(_ code: String, completion: @escaping (Bool, Error?) -> Void) {
        db.collection("groups").whereField("code", isEqualTo: code).getDocuments { snapshot, error in
            if let error = error {
                completion(false, error)
                return
            }

            guard let snapshot = snapshot else {
                completion(false, nil)
                return
            }

            completion(!snapshot.documents.isEmpty, nil)
        }
    }

    // MARK: - User methods

    // Get user role
    func getUserRole(completion: @escaping (String?, Error?) -> Void) {
        guard let userId = currentUserId() else {
            completion(nil, NSError(domain: "FirestoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }

        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                completion(nil, NSError(domain: "FirestoreService", code: 2, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }

            let role = data["role"] as? String ?? "Unknown"
            completion(role, nil)
        }
    }

    // MARK: - Firestore Collections Access

    // Get reference to users collection
    func usersCollection() -> CollectionReference {
        return db.collection("users")
    }

    // Get reference to groups collection
    func groupsCollection() -> CollectionReference {
        return db.collection("groups")
    }

    // Get reference to events collection
    func eventsCollection() -> CollectionReference {
        return db.collection("events")
    }

    // Get reference to setlists collection
    func setlistsCollection() -> CollectionReference {
        return db.collection("setlists")
    }

    // Get reference to tasks collection
    func tasksCollection() -> CollectionReference {
        return db.collection("tasks")
    }

    // Get reference to chat rooms collection
    func chatRoomsCollection() -> CollectionReference {
        return db.collection("chatRooms")
    }

    // Get reference to contacts collection
    func contactsCollection() -> CollectionReference {
        return db.collection("contacts")
    }

    // Get reference to finances collection
    func financesCollection() -> CollectionReference {
        return db.collection("finances")
    }
}
