import Vapor

public enum GotenbergError: Error, AbortError, Equatable {
    /// `GotenbergConfiguration.baseURL` is not an absolute `http` or `https` URL.
    case invalidBaseURL
    /// An asset used one of the filenames Gotenberg reserves for the document itself.
    case reservedAssetFilename(String)
    /// Gotenberg answered 200 with no body.
    case emptyResponse
    /// Gotenberg refused or failed the conversion. `message` is the response body as text and
    /// `trace` is the `Gotenberg-Trace` response header, when present.
    case conversionFailed(status: HTTPResponseStatus, message: String, trace: String?)
    /// Gotenberg answered a health or version request with a status the client does not expect.
    case unexpectedStatus(status: HTTPResponseStatus, trace: String?)

    public var status: HTTPResponseStatus {
        switch self {
        case .invalidBaseURL, .reservedAssetFilename:
            return .internalServerError
        case .emptyResponse, .conversionFailed, .unexpectedStatus:
            return .badGateway
        }
    }

    public var reason: String {
        switch self {
        case .invalidBaseURL:
            return "Gotenberg base URL is invalid: expected an absolute http or https URL such as http://gotenberg:3000"
        case .reservedAssetFilename(let filename):
            return "Asset filename '\(filename)' is reserved by Gotenberg: pass it as the document's index, header or footer instead"
        case .emptyResponse:
            return "Gotenberg returned an empty response"
        case .conversionFailed(let status, let message, let trace):
            let detail: String = message.isEmpty ? "no response body" : message
            return "Gotenberg conversion failed with status \(status.code) \(status.reasonPhrase)\(Self.traceSuffix(trace)): \(detail)"
        case .unexpectedStatus(let status, let trace):
            return "Gotenberg returned unexpected status \(status.code) \(status.reasonPhrase)\(Self.traceSuffix(trace))"
        }
    }

    private static func traceSuffix(_ trace: String?) -> String {
        guard let trace: String = trace, !trace.isEmpty else {
            return ""
        }
        return " (trace \(trace))"
    }
}
