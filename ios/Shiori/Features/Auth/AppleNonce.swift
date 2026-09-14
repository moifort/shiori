import CryptoKit
import Foundation

/// Helpers for the Sign in with Apple nonce required by Firebase Auth.
enum AppleNonce {
    /// 32-character URL-safe nonce (uppercase letters, digits, hyphen, underscore).
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    /// SHA-256 hex digest used as the value sent to Apple.
    static func sha256(_ input: String) -> String {
        SHA256
            .hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
