import Foundation


internal protocol HAResponseControllerDelegate: AnyObject {
    func responseController(
        _ controller: HAResponseController,
        didTransitionTo phase: HAResponseControllerPhase
    )
    func responseController(
        _ controller: HAResponseController,
        didReceive response: HAWebSocketResponse
    )
}

internal enum HAResponseControllerPhase: Equatable {
    case auth
    case command(version: String)
    case disconnected(error: Error?, forReset: Bool)

    static func == (lhs: HAResponseControllerPhase, rhs: HAResponseControllerPhase) -> Bool {
        switch (lhs, rhs) {
        case (.auth, .auth):
            return true
        case let (.command(lhsVersion), .command(rhsVersion)):
            return lhsVersion == rhsVersion
        case let (.disconnected(lhsError, lhsReset), .disconnected(rhsError, rhsReset)):
            return lhsError as NSError? == rhsError as NSError? && lhsReset == rhsReset
        default: return false
        }
    }
}

internal protocol HAResponseController: AnyObject {
    var delegate: HAResponseControllerDelegate? { get set }
    var workQueue: DispatchQueue { get set }
    var phase: HAResponseControllerPhase { get }

    func reset()
    func didReceive(
        for identifier: HARequestIdentifier,
        response: Result<(HTTPURLResponse, Data?), Error>
    )
    func manageMessage(_ message: URLSessionWebSocketTask.Message)
    
}

internal class HAResponseControllerImpl: HAResponseController {
    weak var delegate: HAResponseControllerDelegate?
    var workQueue: DispatchQueue = .global()

    private(set) var phase: HAResponseControllerPhase = .disconnected(error: nil, forReset: true) {
        didSet {
            if oldValue != phase {
                HAGlobal.log(.info, "phase transition to \(phase)")
            }
            delegate?.responseController(self, didTransitionTo: phase)
        }
    }

    func reset() {
        phase = .disconnected(error: nil, forReset: true)
    }
    
    func manageMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
            
        case .data( _):
            HAGlobal.log(.error, "Failed. Received data format. Expected String")
            
        case .string(let strMessage):
            
            if strMessage.contains("auth_required") {
                self.phase = .auth
            }
            
            self.manageString(strMessage)
            
        @unknown default:
            fatalError("Failed. Received unknown data format. Expected String")
        }
    }
    
    private func manageString(_ string: String) {
        workQueue.async { [self] in
            let response: HAWebSocketResponse

            do {
                // https://forums.swift.org/t/can-encoding-string-to-data-with-utf8-fail/22437/4
                let data = string.data(using: .utf8)!

                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    throw HAError.internal(debugDescription: "couldn't convert to dictionary")
                }

                response = try HAWebSocketResponse(dictionary: json)
            } catch {
                HAGlobal.log(.error, "text parse error: \(error)")
                return
            }

            switch response {
            case let .auth(state):
                HAGlobal.log(.info, "Received: auth: \(state)")
            case let .event(identifier: identifier, data: _):
                HAGlobal.log(.info, "Received: event: for \(identifier)")
            case let .result(identifier: identifier, result: result):
                switch result {
                case .success:
                    HAGlobal.log(.info, "Received: result success \(identifier)")
                case let .failure(error):
                    HAGlobal.log(.info, "Received: result failure \(identifier): \(error) via \(string)")
                }
            }

            DispatchQueue.main.async { [self] in
                if case let .auth(.ok(version)) = response {
                    phase = .command(version: version)
                }

                delegate?.responseController(self, didReceive: response)
            }
        }
    }

    func didReceive(
        for identifier: HARequestIdentifier,
        response: Result<(HTTPURLResponse, Data?), Error>
    ) {
        let didReceive = HAResetLock { [self] (result: Result<HAData, HAError>) in
            switch result {
            case .success:
                HAGlobal.log(.info, "Received: result success \(identifier)")
            case let .failure(error):
                HAGlobal.log(.info, "Received: result failure \(identifier): \(error)")
            }

            delegate?.responseController(
                self,
                didReceive: .result(identifier: identifier, result: result)
            )
        }

        switch response {
        case let .failure(error):
            didReceive.pop()?(.failure(.underlying(error as NSError)))
        case let .success((urlResponse, data)):
            if urlResponse.statusCode >= 400 {
                let errorMessage: String

                if let data = data, let string = String(data: data, encoding: .utf8) {
                    errorMessage = string
                } else {
                    errorMessage = "Unacceptable status code"
                }

                didReceive.pop()?(.failure(.external(.init(
                    code: String(urlResponse.statusCode),
                    message: errorMessage
                ))))
            } else {
                workQueue.async {
                    do {
                        let result: HAData

                        if let data = data {
                            switch urlResponse.allHeaderFields["Content-Type"] as? String {
                            case "application/json", .none:
                                let value = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                                result = HAData(value: value)
                            default:
                                result = HAData(value: String(data: data, encoding: .utf8))
                            }
                        } else {
                            result = HAData.empty
                        }

                        didReceive.pop()?(.success(result))
                    } catch {
                        didReceive.pop()?(.failure(.underlying(error as NSError)))
                    }
                }
            }
        }
    }
}
