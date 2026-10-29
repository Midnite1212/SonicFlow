import Foundation
import SonicFlowCore

/// One persistent WebSocket to an engine; every send goes through one serial queue so start,
/// audio, and stop always arrive in order. Reconnects while the engine is down.
final class EngineClient: NSObject, URLSessionWebSocketDelegate {
    var onConnectionChange: ((Bool) -> Void)?
    /// The transcript so far, while the user is still speaking.
    var onPartial: ((String) -> Void)?
    let endpoint: EngineEndpoint

    private let retryDelay: TimeInterval
    private let queue = DispatchQueue(label: "sonicflow.engine")
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var task: URLSessionWebSocketTask?
    private var isConnected = false
    private var isClosed = false
    private var pending: ((ServerMessage) -> Void)?

    init(endpoint: EngineEndpoint) {
        self.endpoint = endpoint
        // A paired Mac may be away for hours; this Mac's engine is back within seconds.
        retryDelay = endpoint.isLocal ? 1 : 3
    }

    func connect() {
        queue.async { self.open() }
    }

    /// Stops reconnecting, for a pairing that was removed.
    func close() {
        queue.async {
            self.isClosed = true
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.session.invalidateAndCancel()
            self.fail()
        }
    }

    func begin(_ start: String) {
        queue.async { self.send(.string(start)) }
    }

    func sendAudio(_ chunk: Data) {
        queue.async { self.send(.data(chunk)) }
    }

    func finish(selection: String? = nil, _ completion: @escaping (ServerMessage) -> Void) {
        queue.async {
            self.pending = completion
            // Between a drop and the reconnect nothing would ever answer this stop.
            guard self.task != nil else { return self.fail() }
            self.send(.string(selection.map(ServerMessage.stop(selection:)) ?? ServerMessage.stop))
        }
    }

    private func fail() {
        pending?(.error(message: "engine disconnected"))
        pending = nil
    }

    private func open() {
        guard !isClosed else { return }
        var request = URLRequest(url: endpoint.dictateURL)
        if let token = endpoint.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
        receive(on: task)
    }

    private func send(_ message: URLSessionWebSocketTask.Message) {
        guard let task else { return }
        task.send(message) { [weak self] error in
            guard error != nil else { return }
            self?.queue.async { self?.dropped(task) }
        }
    }

    private func receive(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                switch result {
                case let .success(.string(text)):
                    switch ServerMessage.decode(text) {
                    case let .partial(text): self.onPartial?(text)
                    case let message?:
                        self.pending?(message)
                        self.pending = nil
                    case nil: break
                    }
                    self.receive(on: task)
                case .success:
                    self.receive(on: task)
                case .failure:
                    self.dropped(task)
                }
            }
        }
    }

    private func dropped(_ failed: URLSessionWebSocketTask) {
        guard failed === task else { return }
        task = nil
        failed.cancel(with: .goingAway, reason: nil)
        if isConnected {
            isConnected = false
            onConnectionChange?(false)
        }
        fail()
        queue.asyncAfter(deadline: .now() + retryDelay) { self.open() }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        queue.async {
            guard webSocketTask === self.task, !self.isConnected else { return }
            self.isConnected = true
            self.onConnectionChange?(true)
        }
    }

    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let (disposition, credential) = PinnedTrust.evaluate(challenge, pinned: endpoint.certificateSHA256)
        completionHandler(disposition, credential)
    }
}
