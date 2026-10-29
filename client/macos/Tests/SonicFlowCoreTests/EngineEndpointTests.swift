import Foundation
import Testing

@testable import SonicFlowCore

private let fingerprint = String(repeating: "ab", count: 32)

private func pairingCode(_ payload: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: payload)
    let encoded = data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return EngineEndpoint.pairingPrefix + encoded
}

@Test func pairingCodeGivesAPinnedTLSEndpoint() throws {
    let code = pairingCode(["host": "Richies-Mac-Studio.local", "port": 8766, "token": "t0k", "sha256": fingerprint])
    let endpoint = try #require(EngineEndpoint(pairingCode: "  \(code)\n"))
    #expect(endpoint.token == "t0k")
    #expect(endpoint.certificateSHA256 == fingerprint)
    #expect(!endpoint.isLocal)
    #expect(endpoint.displayName == "Richies Mac Studio")
    #expect(endpoint.dictateURL.absoluteString == "wss://Richies-Mac-Studio.local:8766/v1/dictate")
    #expect(endpoint.baseURL.absoluteString == "https://Richies-Mac-Studio.local:8766")
}

@Test func malformedPairingCodesAreRejected() {
    let valid: [String: Any] = ["host": "studio.local", "port": 8766, "token": "t", "sha256": fingerprint]
    #expect(EngineEndpoint(pairingCode: "") == nil)
    #expect(EngineEndpoint(pairingCode: "sonicflow1.!!!") == nil)
    #expect(EngineEndpoint(pairingCode: pairingCode(valid).replacingOccurrences(of: "sonicflow1.", with: "x.")) == nil)
    #expect(EngineEndpoint(pairingCode: pairingCode(valid.merging(["port": 0]) { $1 })) == nil)
    #expect(EngineEndpoint(pairingCode: pairingCode(valid.merging(["sha256": "abc"]) { $1 })) == nil)
    #expect(EngineEndpoint(pairingCode: pairingCode(valid.merging(["token": ""]) { $1 })) == nil)
}

@Test func localEndpointIsPlainLoopback() {
    #expect(EngineEndpoint.local.isLocal)
    #expect(EngineEndpoint.local.displayName == "This Mac")
    #expect(EngineEndpoint.local.dictateURL.absoluteString == "ws://127.0.0.1:8765/v1/dictate")
}
