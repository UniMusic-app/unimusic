import Foundation
import Network
import UniformTypeIdentifiers

class HTTPResponseServer {
    private var listener: NWListener!
    private let type: UTType?
    private let body: Data

    init(body: Data, type: UTType?) {
        self.type = type
        self.body = body
    }

    public func start() async throws -> URL {
        print("Starting response server")
        listener = try NWListener(using: .tcp, on: .any)

        DispatchQueue.main.sync {
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
        }

        let port = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let port = self.listener.port {
                        continuation.resume(returning: port)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "HTTPServer",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Server started, but it is missing port"]
                        ))
                    }
                case let .failed(error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            listener.start(queue: .global())
        }

        return URL(string: "http://127.0.0.1:\(port)/")!
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global())
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let requestString = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
            print("Received request:\n\(requestString)")

            let headers =
                "HTTP/1.1 200 OK\r\n" +
                "Content-Length: \(self.body.count)\r\n" +
                "Content-Type: \(self.type?.preferredMIMEType ?? "application/octet-stream")\r\n" +
                "Connection: close\r\n" +
                "\r\n"

            let httpResponse = headers.data(using: .utf8)! + self.body

            connection.send(content: httpResponse, completion: .contentProcessed { _ in
                connection.cancel()
                self.stop()
            })
        }
    }

    public func stop() {
        print("Stopping response server")
        listener.cancel()
        listener = nil
    }
}
