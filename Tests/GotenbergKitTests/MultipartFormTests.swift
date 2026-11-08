import Vapor
import XCTest
@testable import GotenbergKit

final class MultipartFormTests: XCTestCase {
    func testByteExactBody() {
        let document: HTMLDocument = HTMLDocument(
            index: "<html><body><img src=\"logo.jpg\"></body></html>",
            footer: "<html><body>Page</body></html>",
            assets: [HTMLDocument.Asset(filename: "logo.jpg", data: ByteBuffer(string: "JPEGDATA"))]
        )
        let form: (contentType: String, body: ByteBuffer) = MultipartForm(boundary: "BOUNDARY").encode(
            fields: ChromiumPageOptions(paperWidth: 8.5).formFields,
            files: document.formFiles
        )

        XCTAssertEqual(form.contentType, "multipart/form-data; boundary=BOUNDARY")
        let expected: String =
            "--BOUNDARY\r\n" +
            "Content-Disposition: form-data; name=\"paperWidth\"\r\n" +
            "\r\n" +
            "8.5\r\n" +
            "--BOUNDARY\r\n" +
            "Content-Disposition: form-data; name=\"files\"; filename=\"index.html\"\r\n" +
            "Content-Type: text/html\r\n" +
            "\r\n" +
            "<html><body><img src=\"logo.jpg\"></body></html>\r\n" +
            "--BOUNDARY\r\n" +
            "Content-Disposition: form-data; name=\"files\"; filename=\"footer.html\"\r\n" +
            "Content-Type: text/html\r\n" +
            "\r\n" +
            "<html><body>Page</body></html>\r\n" +
            "--BOUNDARY\r\n" +
            "Content-Disposition: form-data; name=\"files\"; filename=\"logo.jpg\"\r\n" +
            "Content-Type: image/jpeg\r\n" +
            "\r\n" +
            "JPEGDATA\r\n" +
            "--BOUNDARY--\r\n"
        XCTAssertEqual(String(buffer: form.body), expected)
    }

    func testFilesAreOrderedIndexHeaderFooterAssets() {
        let document: HTMLDocument = HTMLDocument(
            index: "i",
            header: "h",
            footer: "f",
            assets: [
                HTMLDocument.Asset(filename: "b.css", data: ByteBuffer(string: "b")),
                HTMLDocument.Asset(filename: "a.png", data: ByteBuffer(string: "a")),
            ]
        )
        let names: [String] = document.formFiles.map { (file: MultipartForm.File) -> String in file.filename }
        XCTAssertEqual(names, ["index.html", "header.html", "footer.html", "b.css", "a.png"])
    }

    func testDefaultBoundaryIsUnique() {
        let first: MultipartForm = MultipartForm()
        let second: MultipartForm = MultipartForm()
        XCTAssertTrue(first.boundary.hasPrefix("----GotenbergKit"))
        XCTAssertNotEqual(first.boundary, second.boundary)
    }

    func testAssetContentTypeInference() {
        XCTAssertEqual(HTMLDocument.Asset(filename: "logo.JPG", data: ByteBuffer()).contentType, .jpeg)
        XCTAssertEqual(HTMLDocument.Asset(filename: "logo.png", data: ByteBuffer()).contentType, .png)
        XCTAssertEqual(HTMLDocument.Asset(filename: "font.unknownext", data: ByteBuffer()).contentType, .binary)
        XCTAssertEqual(HTMLDocument.Asset(filename: "README", data: ByteBuffer()).contentType, .binary)
        XCTAssertEqual(HTMLDocument.Asset(filename: "trailing.", data: ByteBuffer()).contentType, .binary)
        XCTAssertEqual(
            HTMLDocument.Asset(filename: "data.bin", contentType: .pdf, data: ByteBuffer()).contentType,
            .pdf
        )
    }
}
