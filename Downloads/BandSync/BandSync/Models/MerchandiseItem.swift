import Foundation
import FirebaseFirestore

struct MerchandiseItem: Identifiable, Codable {
    var id: String
    var name: String
    var purchasePrice: Double
    var sellingPrice: Double
    var quantity: Int
    var category: String
    var subcategory: String
    var imageURL: String?
    var lastUpdated: Date
    
    // Computed property for profit margin
    var profitMargin: Double {
        return sellingPrice - purchasePrice
    }
    
    // Computed property for profit margin percentage
    var profitMarginPercentage: Double {
        guard purchasePrice > 0 else { return 0 }
        return (profitMargin / purchasePrice) * 100
    }
    
    // Computed property for total inventory value
    var inventoryValue: Double {
        return Double(quantity) * purchasePrice
    }
    
    // Computed property for potential revenue
    var potentialRevenue: Double {
        return Double(quantity) * sellingPrice
    }
    
    // Function to convert to dictionary for Firebase
    var asDictionary: [String: Any] {
        return [
            "id": id,
            "name": name,
            "purchasePrice": purchasePrice,
            "sellingPrice": sellingPrice,
            "quantity": quantity,
            "category": category,
            "subcategory": subcategory,
            "imageURL": imageURL as Any,
            "lastUpdated": Timestamp(date: lastUpdated)
        ]
    }
    
    // Init from Firebase document
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let purchasePrice = data["purchasePrice"] as? Double,
              let sellingPrice = data["sellingPrice"] as? Double,
              let quantity = data["quantity"] as? Int,
              let category = data["category"] as? String,
              let subcategory = data["subcategory"] as? String else {
            return nil
        }
        
        self.id = document.documentID
        self.name = name
        self.purchasePrice = purchasePrice
        self.sellingPrice = sellingPrice
        self.quantity = quantity
        self.category = category
        self.subcategory = subcategory
        self.imageURL = data["imageURL"] as? String
        
        if let timestamp = data["lastUpdated"] as? Timestamp {
            self.lastUpdated = timestamp.dateValue()
        } else {
            self.lastUpdated = Date()
        }
    }
    
    // Standard initializer
    init(id: String = UUID().uuidString,
         name: String,
         purchasePrice: Double,
         sellingPrice: Double,
         quantity: Int,
         category: String,
         subcategory: String,
         imageURL: String? = nil,
         lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.purchasePrice = purchasePrice
        self.sellingPrice = sellingPrice
        self.quantity = quantity
        self.category = category
        self.subcategory = subcategory
        self.imageURL = imageURL
        self.lastUpdated = lastUpdated
    }
}
