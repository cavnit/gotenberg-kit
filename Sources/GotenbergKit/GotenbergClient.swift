import Foundation
import NIOCore
import Vapor

/// Talks to Gotenberg's Chromium HTML route, health check and version endpoint.
public struct GotenbergClient: Sendable {
    let client: any Client
    let logger: Logger
    let configuration: GotenbergConfiguration

    public init(client: any Client, logger: Logger, configuration: GotenbergConfiguration) {
        self.client = client
        self.logger = logger
        self.configuration = configuration
    }

    /// Converts an HTML document to PDF through Chromium (`POST /forms/chromium/convert/html`).
    ///
    /// Only the options that are set are sent. No retries.
    ///
    /// - Parameters:
    ///   - document: The `index.html` page plus optional header, footer and assets.
    ///   - options: Page and wait options. Unset options use Gotenberg's defaults.
    ///   - outputFilename: Sent as `Gotenberg-Output-Filename`, which names the PDF in
    ///     Gotenberg's `Content-Disposition` response header. Gotenberg adds the `.pdf` extension.
    /// - Returns: The PDF bytes.
    /// - Throws: `GotenbergError.reservedAssetFilename` or `.invalidBaseURL` before sending,
    ///   `.conversionFailed` for any non-200 answer, `.emptyResponse` for a 200 with no body,
    ///   and any transport error from the underlying `Client`.
    public func convertHTML(
        _ document: HTMLDocument,
        options: ChromiumPageOptions = ChromiumPageOptions(),
        outputFilename: String? = nil
    ) async throws -> ByteBuffer {
        try document.validate()
        let url: URI = try uri(configuration.convertHTMLURL)

        let form: (contentType: String, body: ByteBuffer) = MultipartForm().encode(
            fields: options.formFields,
            files: document.formFiles
        )

        var headers: HTTPHeaders = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: form.contentType)
        if let outputFilename: String = outputFilename {
            headers.replaceOrAdd(name: "Gotenberg-Output-Filename", value: outputFilename)
        }

        let timeout: TimeAmount = configuration.timeout
        let response: ClientResponse = try await client.post(url, headers: headers) { (req: inout ClientRequest) in
            req.body = form.body
            req.timeout = timeout
        }

        guard response.status == .ok else {
            let message: String = Self.text(response.body)
            let trace: String? = Self.trace(response)
            logger.error(
                "Gotenberg conversion failed",
                metadata: [
                    "status": .string("\(response.status.code)"),
                    "trace": .string(trace ?? "none"),
                    "message": .string(message),
                ]
            )
            throw GotenbergError.conversionFailed(status: response.status, message: message, trace: trace)
        }

        guard let body: ByteBuffer = response.body, body.readableBytes > 0 else {
            throw GotenbergError.emptyResponse
        }
        return body
    }

    /// Checks Gotenberg's health (`GET /health`).
    ///
    /// - Returns: `true` for any 2xx, `false` for 503 (Gotenberg reports an unhealthy module).
    /// - Throws: `GotenbergError.unexpectedStatus` for any other status, and transport errors as-is.
    public func health() async throws -> Bool {
        let response: ClientResponse = try await get(configuration.healthURL)
        if (200..<300).contains(response.status.code) {
            return true
        }
        if response.status == .serviceUnavailable {
            return false
        }
        throw GotenbergError.unexpectedStatus(status: response.status, trace: Self.trace(response))
    }

    /// Reads Gotenberg's version (`GET /version`), e.g. `9.1.0`.
    ///
    /// - Throws: `GotenbergError.unexpectedStatus` for a non-2xx answer and `.emptyResponse`
    ///   when the body is empty.
    public func version() async throws -> String {
        let response: ClientResponse = try await get(configuration.versionURL)
        guard (200..<300).contains(response.status.code) else {
            throw GotenbergError.unexpectedStatus(status: response.status, trace: Self.trace(response))
        }
        let version: String = Self.text(response.body)
        guard !version.isEmpty else {
            throw GotenbergError.emptyResponse
        }
        return version
    }

    // MARK: - Helpers

    private func get(_ urlString: String) async throws -> ClientResponse {
        let url: URI = try uri(urlString)
        let timeout: TimeAmount = configuration.timeout
        return try await client.get(url) { (req: inout ClientRequest) in
            req.timeout = timeout
        }
    }

    private func uri(_ urlString: String) throws -> URI {
        guard configuration.hasValidBaseURL else {
            throw GotenbergError.invalidBaseURL
        }
        return URI(string: urlString)
    }

    private static func text(_ body: ByteBuffer?) -> String {
        guard let body: ByteBuffer = body else {
            return ""
        }
        return String(buffer: body).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trace(_ response: ClientResponse) -> String? {
        response.headers.first(name: "Gotenberg-Trace")
    }
}
