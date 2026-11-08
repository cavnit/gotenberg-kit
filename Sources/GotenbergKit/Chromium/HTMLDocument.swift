import Foundation
import Vapor

/// The files Gotenberg's Chromium HTML route converts: the `index.html` page, optional
/// header and footer pages, and any assets (images, fonts, stylesheets) the pages reference
/// by filename, e.g. `<img src="logo.jpg">`.
public struct HTMLDocument: Sendable {
    /// Filenames Gotenberg gives special meaning to. They cannot be used for assets.
    static let reservedFilenames: Set<String> = ["index.html", "header.html", "footer.html"]

    /// A file the pages reference by its filename.
    public struct Asset: Sendable {
        public var filename: String
        public var contentType: HTTPMediaType
        public var data: ByteBuffer

        public init(filename: String, contentType: HTTPMediaType, data: ByteBuffer) {
            self.filename = filename
            self.contentType = contentType
            self.data = data
        }

        /// Infers `contentType` from the filename extension, falling back to
        /// `application/octet-stream` when the extension is missing or unknown.
        public init(filename: String, data: ByteBuffer) {
            self.init(filename: filename, contentType: Self.inferContentType(filename), data: data)
        }

        static func inferContentType(_ filename: String) -> HTTPMediaType {
            guard let dot: String.Index = filename.lastIndex(of: "."),
                  dot != filename.index(before: filename.endIndex)
            else {
                return .binary
            }
            let ext: String = String(filename[filename.index(after: dot)...]).lowercased()
            return HTTPMediaType.fileExtension(ext) ?? .binary
        }
    }

    /// The page to convert, sent as `index.html`.
    public var index: ByteBuffer
    /// An optional page repeated at the top of every page, sent as `header.html`.
    public var header: ByteBuffer?
    /// An optional page repeated at the bottom of every page, sent as `footer.html`.
    public var footer: ByteBuffer?
    /// Files the pages reference by filename.
    public var assets: [Asset]

    public init(
        index: ByteBuffer,
        header: ByteBuffer? = nil,
        footer: ByteBuffer? = nil,
        assets: [Asset] = []
    ) {
        self.index = index
        self.header = header
        self.footer = footer
        self.assets = assets
    }

    /// UTF-8 encodes the given HTML strings.
    public init(
        index: String,
        header: String? = nil,
        footer: String? = nil,
        assets: [Asset] = []
    ) {
        self.init(
            index: ByteBuffer(string: index),
            header: header.map { (html: String) -> ByteBuffer in ByteBuffer(string: html) },
            footer: footer.map { (html: String) -> ByteBuffer in ByteBuffer(string: html) },
            assets: assets
        )
    }

    /// Throws `GotenbergError.reservedAssetFilename` for an asset named like the document's own pages.
    func validate() throws {
        for asset: Asset in assets where Self.reservedFilenames.contains(asset.filename.lowercased()) {
            throw GotenbergError.reservedAssetFilename(asset.filename)
        }
    }

    /// The `files` parts in the order index, header, footer, assets.
    var formFiles: [MultipartForm.File] {
        let html: String = "text/html"
        var files: [MultipartForm.File] = [
            MultipartForm.File(filename: "index.html", contentType: html, data: index),
        ]
        if let header: ByteBuffer = header {
            files.append(MultipartForm.File(filename: "header.html", contentType: html, data: header))
        }
        if let footer: ByteBuffer = footer {
            files.append(MultipartForm.File(filename: "footer.html", contentType: html, data: footer))
        }
        for asset: Asset in assets {
            files.append(MultipartForm.File(filename: asset.filename, contentType: asset.contentType.serialize(), data: asset.data))
        }
        return files
    }
}
