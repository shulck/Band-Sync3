import Foundation

class PINCodeManager {
    static let shared = PINCodeManager()

    private let keyChainManager = KeychainManager()
    private let pinEnabledKey = "isPINCodeEnabled"
    private let pinCodeKey = "userPINCode"

    private init() {}

    func isPINCodeEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: pinEnabledKey)
    }

    func setPINCodeEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: pinEnabledKey)
    }

    func savePINCode(_ pinCode: String) throws {
        do {
            try keyChainManager.save(pinCode, for: pinCodeKey)
            setPINCodeEnabled(true)
        } catch {
            throw error
        }
    }

    func validatePINCode(_ pinCode: String) -> Bool {
        do {
            let savedPINCode = try keyChainManager.get(for: pinCodeKey)
            return savedPINCode == pinCode
        } catch KeychainManager.KeychainError.itemNotFound {
            // PIN code not set
            return false
        } catch {
            print("Error validating PIN code: \(error.localizedDescription)")
            return false
        }
    }

    func deletePINCode() {
        do {
            try keyChainManager.delete(for: pinCodeKey)
            setPINCodeEnabled(false)
        } catch {
            print("Error deleting PIN code: \(error.localizedDescription)")
        }
    }
}
