import Foundation
import NIOCore
import Vapor

/// Where Gotenberg lives and how long the client waits for it.
public struct GotenbergConfiguration: Sendable {
    /// The Gotenberg base URL, e.g. `http://gotenberg:3000`. A trailing slash is tolerated,
    /// and a path prefix (for Gotenberg behind a reverse proxy) is kept.
    public let baseURL: String

    /// The client-side request timeout (`ClientRequest.timeout`). Defaults to 30 seconds,
    /// which matches Gotenberg's own default `--api-timeout`.
    public let timeout: TimeAmount

    public init(
        baseURL: String,
        timeout: TimeAmount = .seconds(30)
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    /// `baseURL` without surrounding whitespace or trailing slashes.
    var normalizedBaseURL: String {
        var url: String = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }

    /// True when `baseURL` is an absolute `http` or `https` URL with a host and no query or fragment.
    var hasValidBaseURL: Bool {
        guard let components: URLComponents = URLComponents(string: normalizedBaseURL),
              let scheme: String = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host: String = components.host,
              !host.isEmpty,
              components.query == nil,
              components.fragment == nil
        else {
            return false
        }
        return true
    }

    var convertHTMLURL: String {
        "\(normalizedBaseURL)/forms/chromium/convert/html"
    }

    var healthURL: String {
        "\(normalizedBaseURL)/health"
    }

    var versionURL: String {
        "\(normalizedBaseURL)/version"
    }
}
