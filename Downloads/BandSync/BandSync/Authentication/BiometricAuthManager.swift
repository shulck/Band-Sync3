import Foundation
import LocalAuthentication

class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    enum BiometricType {
        case none
        case touchID
        case faceID
    }
    
    enum AuthError: Error {
        case authenticationFailed
        case userCancelled
        case biometryNotAvailable
        case biometryNotEnrolled
        case biometryLockout
        case passcodeNotSet
        case deviceNotSupported
        case unknown(OSStatus)
        
        var message: String {
            switch self {
            case .authenticationFailed: return "Authentication failed"
            case .userCancelled: return "User cancelled"
            case .biometryNotAvailable: return "Biometric authentication is not available"
            case .biometryNotEnrolled: return "No biometric data is enrolled"
            case .biometryLockout: return "Biometric authentication is locked out"
            case .passcodeNotSet: return "Passcode is not set on the device"
            case .deviceNotSupported: return "Device doesn't support biometric authentication"
            case .unknown: return "Unknown error occurred"
            }
        }
    }
    
    private let context = LAContext()
    private let biometricAuthKey = "BiometricAuthEnabled"
    private let userDefaultsKeyPrefix = "BiometricUser_"
    
    private init() {}
    
    // Check if biometrics is available
    var biometricType: BiometricType {
        // Reset context before checking
        context.invalidate()
        let context = LAContext()
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        default:
            return .none
        }
    }
    
    // Check if device supports biometric auth at all
    func deviceSupportsBiometrics() -> (supported: Bool, error: AuthError?) {
        // Reset context before checking
        context.invalidate()
        let context = LAContext()
        
        var nsError: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError)
        
        if !canEvaluate {
            if let error = nsError {
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    return (false, .biometryNotEnrolled)
                case LAError.biometryLockout.rawValue:
                    return (false, .biometryLockout)
                case LAError.passcodeNotSet.rawValue:
                    return (false, .passcodeNotSet)
                case LAError.biometryNotAvailable.rawValue:
                    return (false, .biometryNotAvailable)
                default:
                    return (false, .deviceNotSupported)
                }
            }
            return (false, nil)
        }
        
        return (true, nil)
    }
    
    // Check if biometric auth is enabled
    func isBiometricAuthEnabled(for userID: String) -> Bool {
        return UserDefaults.standard.bool(forKey: userDefaultsKeyPrefix + userID)
    }
    
    // Enable/disable biometric auth
    func setBiometricAuthEnabled(_ enabled: Bool, for userID: String) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKeyPrefix + userID)
    }
    
    // Save auth credentials in keychain
    func saveAuthCredentials(userID: String, email: String) {
        let keychainService = KeychainManager()
        do {
            try keychainService.save(email, for: userID)
        } catch {
            print("Error saving to keychain: \(error.localizedDescription)")
        }
    }
    
    // Get saved auth credentials
    func getAuthCredentials(for userID: String) -> String? {
        let keychainService = KeychainManager()
        do {
            return try keychainService.get(for: userID)
        } catch {
            print("Error reading from keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Perform biometric authentication
    func authenticate(completion: @escaping (Result<Bool, AuthError>) -> Void) {
        // First check if biometrics are available
        let (supported, error) = deviceSupportsBiometrics()
        
        guard supported else {
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(.biometryNotAvailable))
            }
            return
        }
        
        // Reset context before authenticating
        context.invalidate()
        let context = LAContext()
        
        // Perform authentication
        let reason = "Log in to your account"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(true))
                } else if let error = error {
                    let authError: AuthError
                    switch (error as? LAError)?.code {
                    case .some(.userCancel):
                        authError = .userCancelled
                    case .some(.biometryNotEnrolled):
                        authError = .biometryNotEnrolled
                    case .some(.biometryLockout):
                        authError = .biometryLockout
                    case .some(.passcodeNotSet):
                        authError = .passcodeNotSet
                    default:
                        authError = .authenticationFailed
                    }
                    completion(.failure(authError))
                } else {
                    completion(.failure(.unknown(0)))
                }
            }
        }
    }
    
    // Fallback to passcode if biometrics fail
    func authenticateWithPasscodeFallback(completion: @escaping (Result<Bool, AuthError>) -> Void) {
        // Reset context before authenticating
        context.invalidate()
        let context = LAContext()
        
        // Enable fallback to passcode
        context.localizedFallbackTitle = "Use Passcode"
        
        // Perform authentication
        let reason = "Log in to your account"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(true))
                } else if let error = error {
                    let authError: AuthError
                    switch (error as? LAError)?.code {
                    case .some(.userCancel):
                        authError = .userCancelled
                    case .some(.authenticationFailed):
                        authError = .authenticationFailed
                    default:
                        authError = .unknown(OSStatus((error as NSError).code))
                    }
                    completion(.failure(authError))
                } else {
                    completion(.failure(.unknown(0)))
                }
            }
        }
    }
    
    // Clear all biometric credentials
    func clearAllBiometricData() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys where key.hasPrefix(userDefaultsKeyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
        
        userDefaults.removeObject(forKey: "lastLoggedInUserID")
    }
}
