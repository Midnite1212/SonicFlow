import CryptoKit
import Foundation
import Security
import SonicFlowCore

/// Trusts a paired engine's self-signed certificate only if its SHA-256 matches the pairing code.
final class PinnedTrust: NSObject, URLSessionTaskDelegate {
    private let sha256: String

    init(sha256: String) {
        self.sha256 = sha256
    }

    static func evaluate(
        _ challenge: URLAuthenticationChallenge, pinned sha256: String?
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else { return (.performDefaultHandling, nil) }
        guard let sha256,
            let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        else { return (.cancelAuthenticationChallenge, nil) }
        let digest = SHA256.hash(data: SecCertificateCopyData(leaf) as Data)
            .map { String(format: "%02x", $0) }.joined()
        return digest == sha256 ? (.useCredential, URLCredential(trust: trust)) : (.cancelAuthenticationChallenge, nil)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        Self.evaluate(challenge, pinned: sha256)
    }
}

/// The pairing code holds the engine's token, so it lives in the Keychain rather than defaults.
enum PairingStore {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sonicflow.app.engine",
        kSecAttrAccount as String: "paired-engine",
    ]

    static func load() -> EngineEndpoint? {
        var result: AnyObject?
        var lookup = query
        lookup[kSecReturnData as String] = true
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return EngineEndpoint(pairingCode: String(decoding: data, as: UTF8.self))
    }

    static func save(_ code: String) throws {
        remove()
        var item = query
        item[kSecValueData as String] = Data(code.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EngineAPI.Failure(errorDescription: "Couldn't save the pairing (\(status)).")
        }
    }

    static func remove() {
        SecItemDelete(query as CFDictionary)
    }
}
