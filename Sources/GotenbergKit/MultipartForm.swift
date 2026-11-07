import Foundation
import Vapor

/// Builds a `multipart/form-data` body for Gotenberg: field parts first, in the given order,
/// then one `files` part per file, in the given order. CRLF line endings throughout.
struct MultipartForm: Sendable {
    struct File: Sendable {
        let filename: String
        let contentType: String
        let data: ByteBuffer
    }

    let boundary: String

    init(boundary: String = "----GotenbergKit" + UUID().uuidString) {
        self.boundary = boundary
    }

    func encode(
        fields: [(name: String, value: String)],
        files: [File]
    ) -> (contentType: String, body: ByteBuffer) {
        var body: ByteBuffer = ByteBufferAllocator().buffer(capacity: 0)

        for field: (name: String, value: String) in fields {
            body.writeString("--\(boundary)\r\n")
            body.writeString("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            body.writeString("\(field.value)\r\n")
        }

        for file: File in files {
            body.writeString("--\(boundary)\r\n")
            body.writeString("Content-Disposition: form-data; name=\"files\"; filename=\"\(file.filename)\"\r\n")
            body.writeString("Content-Type: \(file.contentType)\r\n\r\n")
            body.writeImmutableBuffer(file.data)
            body.writeString("\r\n")
        }

        body.writeString("--\(boundary)--\r\n")

        return (contentType: "multipart/form-data; boundary=\(boundary)", body: body)
    }
}
