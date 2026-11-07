# GotenbergKit

A Vapor client for the Chromium HTML to PDF route of [Gotenberg](https://gotenberg.dev). It does one thing: send an `index.html` (plus an optional header, footer and assets) to `/forms/chromium/convert/html` and hand back the PDF bytes. It also wraps Gotenberg's `/health` and `/version` endpoints.

It works with both Gotenberg 8 and Gotenberg 9. Gotenberg 9 answers `400` to any request carrying a Gotenberg 8 form field it renamed or removed. The [thoven87/gotenberg-kit](https://github.com/thoven87/gotenberg-kit) package sends `generateDocumentOutline`, `generateTaggedPdf`, `pdfua` and `splitUnify` on every request, so it cannot talk to Gotenberg 9. This package replaces it for HTML to PDF. It sends only the fields you set, and only fields whose names are the same in Gotenberg 8 and 9.

## Requirements

- Swift 6.1+
- macOS 15.0+ or Linux

## Installation

Add GotenbergKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/cavnit/gotenberg-kit.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "GotenbergKit", package: "gotenberg-kit"),
        ]
    ),
]
```

## Configuration

```swift
import GotenbergKit

func configure(_ app: Application) throws {
    app.gotenberg.configuration = GotenbergConfiguration(
        baseURL: Environment.get("GOTENBERG_URL") ?? "http://gotenberg:3000"
    )
}
```

| Environment Variable | Description                                              |
|----------------------|----------------------------------------------------------|
| `GOTENBERG_URL`      | Gotenberg base URL, e.g. `http://gotenberg:3000`         |

`baseURL` tolerates a trailing slash and keeps a path prefix (for Gotenberg behind a reverse proxy). `timeout` defaults to 30 seconds, which matches Gotenberg's own default `--api-timeout`. It is the client-side request timeout. If you raise Gotenberg's `--api-timeout`, raise this as well:

```swift
app.gotenberg.configuration = GotenbergConfiguration(
    baseURL: "http://gotenberg:3000",
    timeout: .seconds(60)
)
```

## Usage

The client is available as `app.gotenberg.client` and, inside a route handler, `req.gotenberg.client`.

The pages reference assets by filename. This example renders an agreement on US Letter with a footer on every page and a logo:

```swift
let logo: ByteBuffer = try await req.fileio.collectFile(at: "Resources/logo.jpg")

let document: HTMLDocument = HTMLDocument(
    index: """
    <html>
      <body>
        <img src="logo.jpg" alt="Logo">
        <h1>User Agreement</h1>
        <p>...</p>
      </body>
    </html>
    """,
    footer: """
    <html>
      <body style="font-size: 8px; text-align: center; width: 100%;">
        Page <span class="pageNumber"></span> of <span class="totalPages"></span>
      </body>
    </html>
    """,
    assets: [
        HTMLDocument.Asset(filename: "logo.jpg", data: logo),
    ]
)

let options: ChromiumPageOptions = ChromiumPageOptions(
    paperWidth: 8.5,
    paperHeight: 11,
    marginTop: 1,
    marginBottom: 1,
    marginLeft: 0.25,
    marginRight: 0.25
)

let pdf: ByteBuffer = try await req.gotenberg.client.convertHTML(
    document,
    options: options,
    outputFilename: "agreement"
)
```

- `HTMLDocument` takes `String` or `ByteBuffer` pages. The page is sent as `index.html`, the header as `header.html` and the footer as `footer.html`. Those three filenames cannot be used for assets.
- `HTMLDocument.Asset(filename:data:)` infers the content type from the filename extension, falling back to `application/octet-stream`. Pass `contentType:` to set it yourself.
- Paper sizes and margins are in inches.
- `outputFilename` is sent as the `Gotenberg-Output-Filename` header. Gotenberg adds the `.pdf` extension.

### Page options

Every `ChromiumPageOptions` property is optional. An unset property is not sent, so Gotenberg uses its own default.

| Property            | Form field          | Meaning                                                    |
|---------------------|---------------------|------------------------------------------------------------|
| `paperWidth`        | `paperWidth`        | Paper width in inches                                      |
| `paperHeight`       | `paperHeight`       | Paper height in inches                                     |
| `marginTop`         | `marginTop`         | Top margin in inches                                       |
| `marginBottom`      | `marginBottom`      | Bottom margin in inches                                    |
| `marginLeft`        | `marginLeft`        | Left margin in inches                                      |
| `marginRight`       | `marginRight`       | Right margin in inches                                     |
| `preferCssPageSize` | `preferCssPageSize` | Let a CSS `@page` size win over the paper size             |
| `printBackground`   | `printBackground`   | Print background graphics                                  |
| `omitBackground`    | `omitBackground`    | Hide the default white background (with `printBackground`) |
| `landscape`         | `landscape`         | Landscape orientation                                      |
| `scale`             | `scale`             | Rendering scale                                            |
| `singlePage`        | `singlePage`        | Put the whole document on one page                         |
| `waitDelay`         | `waitDelay`         | Seconds to wait before converting, sent as e.g. `2s`       |
| `waitForExpression` | `waitForExpression` | JavaScript expression to wait on before converting         |

## Health check

```swift
let healthy: Bool = try await app.gotenberg.client.health()
let version: String = try await app.gotenberg.client.version() // e.g. "9.1.0"
```

`health()` returns `true` for a 2xx answer and `false` for `503` (Gotenberg reports an unhealthy module). Any other status throws `GotenbergError.unexpectedStatus`. Connection errors are thrown as they come from the underlying client.

## Gotenberg compatibility

Works with Gotenberg 8.x and 9.x.

These are the only things GotenbergKit ever sends:

- `POST /forms/chromium/convert/html`, `GET /health`, `GET /version`
- multipart `files` parts named `index.html`, `header.html`, `footer.html` and your asset filenames
- the form fields in the table above, and only the ones you set
- the `Gotenberg-Output-Filename` header, only when you pass `outputFilename`

The routes, the `files` part and the paper size and margin fields are unchanged between Gotenberg 8 and 9. Everything else is left out on purpose: `paperSize`, `nativePages`, `nativeBookmarks`, `nativeTaggedPdf`, `pdfa`, `pdfua` and every split, merge and metadata field either differ between Gotenberg 8 and 9 or exist only in 9, and Gotenberg 9 rejects a request that carries a field it does not know. The client also sends no `Gotenberg-Wait-Timeout` header, because Gotenberg has no such header.

## Errors

All errors are `GotenbergError`, which conforms to Vapor's `AbortError`:

| Case                                          | HTTP status | When                                                          |
|-----------------------------------------------|-------------|---------------------------------------------------------------|
| `invalidBaseURL`                              | 500         | `baseURL` is not an absolute `http` or `https` URL             |
| `reservedAssetFilename(String)`               | 500         | An asset is named `index.html`, `header.html` or `footer.html` |
| `emptyResponse`                               | 502         | Gotenberg answered 200 with no body                            |
| `conversionFailed(status:message:trace:)`     | 502         | Gotenberg answered anything but 200 to a conversion            |
| `unexpectedStatus(status:trace:)`             | 502         | A health or version request got an unexpected status          |

`conversionFailed` carries Gotenberg's response body as `message` and the `Gotenberg-Trace` response header as `trace`. Gotenberg 9's error bodies name the offending form field, and Gotenberg 8's say what Chromium rejected, so log the message. The client also logs failed conversions at `.error` with the status, trace and message. There are no retries.

## Testing

The package's tests need no Gotenberg. `GotenbergClient` takes any Vapor `Client`, and the tests use a stub client that records each request and answers with a canned response:

```swift
let client: GotenbergClient = GotenbergClient(
    client: stubClient,
    logger: Logger(label: "test"),
    configuration: GotenbergConfiguration(baseURL: "http://gotenberg:3000")
)
```

Your own app can do the same, or swap the client for the whole app with `app.clients.use { _ in stubClient }`.

```bash
swift test
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
