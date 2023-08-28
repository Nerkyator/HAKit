//
//  SocketStream.swift
//  Skynet
//
//  Created by Lorenzo Leasi on 25/03/23.
//

/// Inspired by Dony Wals at https://www.donnywals.com/iterating-over-web-socket-messages-with-async-await-in-swift/
/// Basically same wonderful and working implementation. Just tweaked something and added `send` method
import Foundation

typealias WebSocketStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
                                                    
class SocketStream: AsyncSequence {
    let id: UUID = UUID()
    typealias AsyncIterator = WebSocketStream.Iterator
    typealias Element = URLSessionWebSocketTask.Message

    private var continuation: WebSocketStream.Continuation?
    let task: URLSessionWebSocketTask
    
    let url: URL

    private lazy var stream: WebSocketStream = {
        return WebSocketStream { continuation in
            self.continuation = continuation
            waitForNextValue()
        }
    }()

    private func waitForNextValue() {
        guard task.closeCode == .invalid else {
            continuation?.finish()
            return
        }

        task.receive(completionHandler: { [weak self] result in
            guard let continuation = self?.continuation else {
                return
            }

            do {
                let message = try result.get()
                continuation.yield(message)
                self?.waitForNextValue()
            } catch {
                continuation.finish(throwing: error)
            }
        })
    }

    init(withURL url: URL) {
        self.url = url
        self.task = URLSession.shared.webSocketTask(with: url)
        task.resume()
    }

    deinit {
        continuation?.finish()
    }

    func makeAsyncIterator() -> AsyncIterator {
        return stream.makeAsyncIterator()
    }

    func cancel() async throws {
        task.cancel(with: .goingAway, reason: nil)
        continuation?.finish()
    }
    
    func send(_ stringMessage: String) async throws {
        return try await self.task.send(URLSessionWebSocketTask.Message.string(stringMessage))
    }
}
