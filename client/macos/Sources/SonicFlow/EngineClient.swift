import Foundation
import SonicFlowCore

/// One persistent WebSocket to the engine; every send goes through one serial queue so start,
/// audio, and stop always arrive in order. Reconnects every second while the engine is down.
final class EngineClient: NSObject, URLSessionWebSocketDelegate {
    var onConnectionChange: ((Bool) -> Void)?

    private let url: URL
    private let queue = DispatchQueue(label: "sonicflow.engine")
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var task: URLSessionWebSocketTask?
    private var isConnected = false
    private var pending: ((ServerMessage) -> Void)?

    init(url: URL) {
        self.url = url
    }

    func connect() {
        queue.async { self.open() }
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
            self.send(.string(selection.map(ServerMessage.stop(selection:)) ?? ServerMessage.stop))
        }
    }

    private func open() {
        let task = session.webSocketTask(with: url)
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
                    if let message = ServerMessage.decode(text), !Self.isPartial(message) {
                        self.pending?(message)
                        self.pending = nil
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

    private static func isPartial(_ message: ServerMessage) -> Bool {
        if case .partial = message { return true }
        return false
    }

    private func dropped(_ failed: URLSessionWebSocketTask) {
        guard failed === task else { return }
        task = nil
        failed.cancel(with: .goingAway, reason: nil)
        if isConnected {
            isConnected = false
            onConnectionChange?(false)
        }
        pending?(.error(message: "engine disconnected"))
        pending = nil
        queue.asyncAfter(deadline: .now() + 1) { self.open() }
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
}
