// Class for encrypting local data
import Foundation
import CommonCrypto

class DataEncryptionManager {
    static let shared = DataEncryptionManager()

    private let keyChainManager = KeychainManager()
    private let encryptionKeyIdentifier = "com.bandsync.encryptionKey"

    private init() {
        // Check for encryption key during initialization
        if getEncryptionKey() == nil {
            generateEncryptionKey()
        }
    }

    // Generate and save encryption key
    private func generateEncryptionKey() {
        var keyData = Data(count: 32) // 256-bit key
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }

        if result == errSecSuccess {
            do {
                try keyChainManager.save(keyData.base64EncodedString(), for: encryptionKeyIdentifier)
            } catch {
                print("Error saving encryption key: \(error.localizedDescription)")
            }
        }
    }

    // Retrieve encryption key
    private func getEncryptionKey() -> Data? {
        do {
            let keyString = try keyChainManager.get(for: encryptionKeyIdentifier)
            return Data(base64Encoded: keyString)
        } catch {
            return nil
        }
    }

    // Encrypt data
    func encrypt(data: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            print("Encryption key not available")
            return nil
        }

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted = 0

        let iv = generateIV()

        let status = key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress!,
                            key.count,
                            ivBytes.baseAddress!,
                            dataBytes.baseAddress!,
                            data.count,
                            bufferBytes.baseAddress!,
                            bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }

        if status != kCCSuccess {
            print("Error encrypting data: \(status)")
            return nil
        }

        buffer.count = numBytesEncrypted

        // Add IV to the beginning of the encrypted data
        var encryptedData = iv
        encryptedData.append(buffer)

        return encryptedData
    }

    // Decrypt data
    func decrypt(encryptedData: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            print("Encryption key not available")
            return nil
        }

        // Extract IV from the beginning of the encrypted data
        let iv = encryptedData.prefix(16)
        let encryptedBytes = encryptedData.suffix(from: 16)

        let bufferSize = encryptedBytes.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0

        let status = key.withUnsafeBytes { keyBytes in
            encryptedBytes.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress!,
                            key.count,
                            ivBytes.baseAddress!,
                            dataBytes.baseAddress!,
                            encryptedBytes.count,
                            bufferBytes.baseAddress!,
                            bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        if status != kCCSuccess {
            print("Error decrypting data: \(status)")
            return nil
        }

        buffer.count = numBytesDecrypted
        return buffer
    }

    // Generate initialization vector (IV)
    private func generateIV() -> Data {
        var iv = Data(count: kCCBlockSizeAES128)
        let result = iv.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, $0.baseAddress!)
        }

        if result != errSecSuccess {
            print("Error generating IV: \(result)")
        }

        return iv
    }

    // Automatically wipe data after a certain period
    func scheduleDataWipe(after days: Int) {
        // Save the last use date
        UserDefaults.standard.set(Date(), forKey: "app_last_use_date")
    }

    // Check if data wipe is needed on launch
    func checkDataWipe(days: Int) -> Bool {
        if let lastUseDate = UserDefaults.standard.object(forKey: "app_last_use_date") as? Date {
            let calendar = Calendar.current
            if let expirationDate = calendar.date(byAdding: .day, value: days, to: lastUseDate) {
                if Date() > expirationDate {
                    return true
                }
            }
        }
        return false
    }

    // Perform data wipe
    func performDataWipe() {
        // Clear encryption key
        try? keyChainManager.delete(for: encryptionKeyIdentifier)

        // Reset biometric settings
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys

        for key in allKeys where key.hasPrefix("BiometricUser_") {
            userDefaults.removeObject(forKey: key)
        }

        userDefaults.removeObject(forKey: "lastLoggedInUserID")
        userDefaults.synchronize()

        // Generate a new key
        generateEncryptionKey()
    }
}
