import Vapor
import XCTest
@testable import GotenbergKit

final class GotenbergClientTests: XCTestCase {
    private let base: String = "http://gotenberg:3000"

    private func makeClient(_ stub: StubClient, baseURL: String? = nil) -> GotenbergClient {
        GotenbergClient(
            client: stub,
            logger: Logger(label: "gotenberg-kit.tests"),
            configuration: GotenbergConfiguration(baseURL: baseURL ?? base, timeout: .seconds(45))
        )
    }

    private func assertThrows(
        _ expected: GotenbergError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("Expected \(expected) to be thrown", file: file, line: line)
        } catch let error as GotenbergError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected \(expected), got \(error)", file: file, line: line)
        }
    }

    // MARK: - convertHTML

    func testConvertHTMLPostsMultipartAndReturnsPDF() async throws {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: "%PDF-1.7 stub"))
        let document: HTMLDocument = HTMLDocument(
            index: "<html>agreement</html>",
            footer: "<html>footer</html>",
            assets: [HTMLDocument.Asset(filename: "logo.jpg", data: ByteBuffer(string: "JPEG"))]
        )

        let pdf: ByteBuffer = try await makeClient(stub).convertHTML(
            document,
            options: ChromiumPageOptions(paperWidth: 8.5, paperHeight: 11),
            outputFilename: "agreement"
        )

        XCTAssertEqual(String(buffer: pdf), "%PDF-1.7 stub")
        XCTAssertEqual(stub.requests.count, 1)
        let seen: StubClient.Seen = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(seen.method, .POST)
        XCTAssertEqual(seen.url, "http://gotenberg:3000/forms/chromium/convert/html")
        let contentType: String = try XCTUnwrap(seen.headers.first(name: .contentType))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="), contentType)
        XCTAssertEqual(seen.headers.first(name: "Gotenberg-Output-Filename"), "agreement")
        XCTAssertNil(seen.headers.first(name: "Gotenberg-Wait-Timeout"))
        XCTAssertEqual(seen.timeout, .seconds(45))

        let body: String = try XCTUnwrap(seen.body)
        let boundary: String = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        XCTAssertTrue(body.hasPrefix("--\(boundary)\r\n"))
        XCTAssertTrue(body.hasSuffix("--\(boundary)--\r\n"))
        XCTAssertTrue(body.contains("name=\"paperWidth\"\r\n\r\n8.5\r\n"))
        XCTAssertTrue(body.contains("name=\"paperHeight\"\r\n\r\n11\r\n"))
        XCTAssertTrue(body.contains("filename=\"index.html\""))
        XCTAssertTrue(body.contains("filename=\"footer.html\""))
        XCTAssertTrue(body.contains("filename=\"logo.jpg\""))
        XCTAssertFalse(body.contains("filename=\"header.html\""))
        for removedField: String in ["generateDocumentOutline", "generateTaggedPdf", "pdfua", "splitUnify", "pdfa", "paperSize"] {
            XCTAssertFalse(body.contains("name=\"\(removedField)\""), removedField)
        }
    }

    func testConvertHTMLWithDefaultOptionsSendsOnlyFiles() async throws {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: "%PDF"))
        _ = try await makeClient(stub).convertHTML(HTMLDocument(index: "<html></html>"))

        let seen: StubClient.Seen = try XCTUnwrap(stub.requests.first)
        let body: String = try XCTUnwrap(seen.body)
        XCTAssertEqual(body.components(separatedBy: "Content-Disposition:").count - 1, 1)
        XCTAssertTrue(body.contains("name=\"files\"; filename=\"index.html\""))
        XCTAssertNil(seen.headers.first(name: "Gotenberg-Output-Filename"))
    }

    func testConvertHTMLToleratesTrailingSlashInBaseURL() async throws {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: "%PDF"))
        _ = try await makeClient(stub, baseURL: "http://gotenberg:3000/").convertHTML(HTMLDocument(index: "x"))
        XCTAssertEqual(stub.requests.first?.url, "http://gotenberg:3000/forms/chromium/convert/html")
    }

    func testConvertHTMLBadRequestThrowsConversionFailedWithMessageAndTrace() async {
        var headers: HTTPHeaders = HTTPHeaders()
        headers.add(name: "Gotenberg-Trace", value: "abc")
        let message: String = "Invalid form data: form field 'pdfua' is unknown to this route"
        let stub: StubClient = StubClient(response: StubClient.response(.badRequest, body: message, headers: headers))

        await assertThrows(.conversionFailed(status: .badRequest, message: message, trace: "abc")) {
            _ = try await self.makeClient(stub).convertHTML(HTMLDocument(index: "x"))
        }
        XCTAssertEqual(stub.requests.count, 1, "no retries")
    }

    func testConvertHTMLServerErrorWithoutBodyOrTrace() async {
        let stub: StubClient = StubClient(response: StubClient.response(.internalServerError))
        await assertThrows(.conversionFailed(status: .internalServerError, message: "", trace: nil)) {
            _ = try await self.makeClient(stub).convertHTML(HTMLDocument(index: "x"))
        }
        XCTAssertEqual(stub.requests.count, 1, "no retries")
    }

    func testConvertHTMLEmptyBodyThrowsEmptyResponse() async {
        let stub: StubClient = StubClient(response: StubClient.response(.ok))
        await assertThrows(.emptyResponse) {
            _ = try await self.makeClient(stub).convertHTML(HTMLDocument(index: "x"))
        }
    }

    func testReservedAssetFilenameThrowsBeforeSending() async {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: "%PDF"))
        for name: String in ["index.html", "header.html", "footer.html", "Footer.HTML"] {
            let document: HTMLDocument = HTMLDocument(
                index: "x",
                assets: [HTMLDocument.Asset(filename: name, data: ByteBuffer(string: "y"))]
            )
            await assertThrows(.reservedAssetFilename(name)) {
                _ = try await self.makeClient(stub).convertHTML(document)
            }
        }
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testInvalidBaseURLThrowsBeforeSending() async {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: "%PDF"))
        for baseURL: String in ["", "gotenberg:3000", "ftp://gotenberg", "http://"] {
            await assertThrows(.invalidBaseURL) {
                _ = try await self.makeClient(stub, baseURL: baseURL).convertHTML(HTMLDocument(index: "x"))
            }
        }
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testTransportErrorPropagates() async {
        let stub: StubClient = StubClient { (_: StubClient.Seen) -> Result<ClientResponse, any Error> in
            .failure(StubClient.TransportFailure())
        }
        do {
            _ = try await makeClient(stub).convertHTML(HTMLDocument(index: "x"))
            XCTFail("Expected a transport error")
        } catch is StubClient.TransportFailure {
        } catch {
            XCTFail("Expected TransportFailure, got \(error)")
        }
    }

    // MARK: - health

    func testHealthOKIsTrue() async throws {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: #"{"status":"up"}"#))
        let healthy: Bool = try await makeClient(stub).health()
        XCTAssertTrue(healthy)
        let seen: StubClient.Seen = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(seen.method, .GET)
        XCTAssertEqual(seen.url, "http://gotenberg:3000/health")
    }

    func testHealthServiceUnavailableIsFalse() async throws {
        let stub: StubClient = StubClient(response: StubClient.response(.serviceUnavailable, body: #"{"status":"down"}"#))
        let healthy: Bool = try await makeClient(stub).health()
        XCTAssertFalse(healthy)
    }

    func testHealthOtherStatusThrows() async {
        var headers: HTTPHeaders = HTTPHeaders()
        headers.add(name: "Gotenberg-Trace", value: "t1")
        let stub: StubClient = StubClient(response: StubClient.response(.notFound, headers: headers))
        await assertThrows(.unexpectedStatus(status: .notFound, trace: "t1")) {
            _ = try await self.makeClient(stub).health()
        }
    }

    // MARK: - version

    func testVersionReturnsTrimmedBody() async throws {
        let stub: StubClient = StubClient(response: StubClient.response(.ok, body: "9.1.0\n"))
        let version: String = try await makeClient(stub).version()
        XCTAssertEqual(version, "9.1.0")
        XCTAssertEqual(stub.requests.first?.url, "http://gotenberg:3000/version")
        XCTAssertEqual(stub.requests.first?.method, .GET)
    }

    func testVersionNonSuccessThrows() async {
        let stub: StubClient = StubClient(response: StubClient.response(.badGateway))
        await assertThrows(.unexpectedStatus(status: .badGateway, trace: nil)) {
            _ = try await self.makeClient(stub).version()
        }
    }
}

final class GotenbergErrorTests: XCTestCase {
    func testStatuses() {
        XCTAssertEqual(GotenbergError.invalidBaseURL.status, .internalServerError)
        XCTAssertEqual(GotenbergError.reservedAssetFilename("index.html").status, .internalServerError)
        XCTAssertEqual(GotenbergError.emptyResponse.status, .badGateway)
        XCTAssertEqual(GotenbergError.conversionFailed(status: .badRequest, message: "m", trace: nil).status, .badGateway)
        XCTAssertEqual(GotenbergError.unexpectedStatus(status: .notFound, trace: nil).status, .badGateway)
    }

    func testReasonsIncludeMessageAndTrace() {
        let error: GotenbergError = .conversionFailed(
            status: .badRequest,
            message: "Invalid form data: form field 'pdfua' is unknown to this route",
            trace: "abc"
        )
        XCTAssertEqual(
            error.reason,
            "Gotenberg conversion failed with status 400 Bad Request (trace abc): Invalid form data: form field 'pdfua' is unknown to this route"
        )
        XCTAssertEqual(
            GotenbergError.unexpectedStatus(status: .notFound, trace: nil).reason,
            "Gotenberg returned unexpected status 404 Not Found"
        )
        XCTAssertTrue(GotenbergError.reservedAssetFilename("header.html").reason.contains("'header.html'"))
    }
}

final class GotenbergConfigurationTests: XCTestCase {
    func testURLs() {
        let config: GotenbergConfiguration = GotenbergConfiguration(baseURL: "http://gotenberg:3000//")
        XCTAssertEqual(config.convertHTMLURL, "http://gotenberg:3000/forms/chromium/convert/html")
        XCTAssertEqual(config.healthURL, "http://gotenberg:3000/health")
        XCTAssertEqual(config.versionURL, "http://gotenberg:3000/version")
        XCTAssertEqual(config.timeout, .seconds(30))
        XCTAssertTrue(config.hasValidBaseURL)
    }

    func testPathPrefixIsKept() {
        let config: GotenbergConfiguration = GotenbergConfiguration(baseURL: "https://pdf.example.com/gotenberg/")
        XCTAssertTrue(config.hasValidBaseURL)
        XCTAssertEqual(config.healthURL, "https://pdf.example.com/gotenberg/health")
    }
}

final class ApplicationGotenbergTests: XCTestCase {
    func testConfigurationRoundTripsThroughApplicationStorage() async throws {
        let app: Application = try await Application.make(.testing)
        app.gotenberg.configuration = GotenbergConfiguration(baseURL: "http://gotenberg:3000", timeout: .seconds(10))
        XCTAssertEqual(app.gotenberg.configuration.baseURL, "http://gotenberg:3000")
        XCTAssertEqual(app.gotenberg.client.configuration.timeout, .seconds(10))
        try await app.asyncShutdown()
    }
}
