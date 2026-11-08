import Foundation
import NIOCore
import Vapor

/// A `Client` that answers every request from a handler closure and records what it was sent,
/// so `GotenbergClient` can be tested without a running Gotenberg.
final class StubClient: Client, @unchecked Sendable {
    struct Seen: Sendable {
        let method: HTTPMethod
        let url: String
        let headers: HTTPHeaders
        let body: String?
        let timeout: TimeAmount?
    }

    typealias Handler = @Sendable (Seen) -> Result<ClientResponse, any Error>

    let eventLoop: any EventLoop
    private let handler: Handler
    private let lock: NSLock = NSLock()
    private var recorded: [Seen] = []

    init(eventLoop: any EventLoop = MultiThreadedEventLoopGroup.singleton.any(), handler: @escaping Handler) {
        self.eventLoop = eventLoop
        self.handler = handler
    }

    /// Answers every request with `response`.
    convenience init(response: ClientResponse) {
        self.init { (_: Seen) -> Result<ClientResponse, any Error> in .success(response) }
    }

    var requests: [Seen] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func delegating(to eventLoop: any EventLoop) -> any Client {
        return self
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        let body: String? = request.body.map { (buffer: ByteBuffer) -> String in String(buffer: buffer) }
        let seen: Seen = Seen(
            method: request.method,
            url: request.url.string,
            headers: request.headers,
            body: body,
            timeout: request.timeout
        )
        lock.lock()
        recorded.append(seen)
        lock.unlock()
        switch handler(seen) {
        case .success(let response):
            return eventLoop.makeSucceededFuture(response)
        case .failure(let error):
            return eventLoop.makeFailedFuture(error)
        }
    }

    // MARK: - Canned responses

    static func response(
        _ status: HTTPStatus,
        body: String? = nil,
        headers: HTTPHeaders = [:]
    ) -> ClientResponse {
        return ClientResponse(status: status, headers: headers, body: body.map { (text: String) -> ByteBuffer in ByteBuffer(string: text) })
    }

    /// A stand-in transport error (connection refused / timeout / DNS).
    struct TransportFailure: Error, CustomStringConvertible {
        var description: String { "stub transport failure" }
    }
}
