import Foundation

/// Page and wait options for Gotenberg's Chromium HTML route.
///
/// Every property is optional and `nil` by default. A `nil` property is not sent at all, so
/// Gotenberg applies its own default. Only form fields whose names and meanings are the same
/// in Gotenberg 8 and Gotenberg 9 are offered here.
public struct ChromiumPageOptions: Sendable, Equatable {
    /// Paper width in inches (`paperWidth`). Unset = Gotenberg's default.
    public var paperWidth: Double?
    /// Paper height in inches (`paperHeight`). Unset = Gotenberg's default.
    public var paperHeight: Double?
    /// Top margin in inches (`marginTop`). Unset = Gotenberg's default.
    public var marginTop: Double?
    /// Bottom margin in inches (`marginBottom`). Unset = Gotenberg's default.
    public var marginBottom: Double?
    /// Left margin in inches (`marginLeft`). Unset = Gotenberg's default.
    public var marginLeft: Double?
    /// Right margin in inches (`marginRight`). Unset = Gotenberg's default.
    public var marginRight: Double?
    /// Let a CSS `@page` size in the document win over `paperWidth` / `paperHeight`
    /// (`preferCssPageSize`). Unset = Gotenberg's default.
    public var preferCssPageSize: Bool?
    /// Print background graphics (`printBackground`). Unset = Gotenberg's default.
    public var printBackground: Bool?
    /// Hide the default white background so the PDF can have transparency (`omitBackground`).
    /// Only has an effect together with `printBackground`. Unset = Gotenberg's default.
    public var omitBackground: Bool?
    /// Landscape orientation (`landscape`). Unset = Gotenberg's default.
    public var landscape: Bool?
    /// Rendering scale (`scale`). Unset = Gotenberg's default.
    public var scale: Double?
    /// Put the whole document on one page (`singlePage`). Unset = Gotenberg's default.
    public var singlePage: Bool?
    /// Seconds to wait before converting, sent as a duration such as `2s` or `0.5s`
    /// (`waitDelay`). Unset = Gotenberg's default.
    public var waitDelay: Double?
    /// A JavaScript expression Gotenberg waits on to become true before converting
    /// (`waitForExpression`), e.g. `window.status === 'ready'`. Unset = Gotenberg's default.
    public var waitForExpression: String?

    public init(
        paperWidth: Double? = nil,
        paperHeight: Double? = nil,
        marginTop: Double? = nil,
        marginBottom: Double? = nil,
        marginLeft: Double? = nil,
        marginRight: Double? = nil,
        preferCssPageSize: Bool? = nil,
        printBackground: Bool? = nil,
        omitBackground: Bool? = nil,
        landscape: Bool? = nil,
        scale: Double? = nil,
        singlePage: Bool? = nil,
        waitDelay: Double? = nil,
        waitForExpression: String? = nil
    ) {
        self.paperWidth = paperWidth
        self.paperHeight = paperHeight
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.marginLeft = marginLeft
        self.marginRight = marginRight
        self.preferCssPageSize = preferCssPageSize
        self.printBackground = printBackground
        self.omitBackground = omitBackground
        self.landscape = landscape
        self.scale = scale
        self.singlePage = singlePage
        self.waitDelay = waitDelay
        self.waitForExpression = waitForExpression
    }

    /// The form fields to send, non-nil values only, always in declaration order.
    var formFields: [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = []

        func add(_ name: String, _ value: String?) {
            if let value: String = value {
                fields.append((name: name, value: value))
            }
        }

        add("paperWidth", paperWidth.map(Self.format))
        add("paperHeight", paperHeight.map(Self.format))
        add("marginTop", marginTop.map(Self.format))
        add("marginBottom", marginBottom.map(Self.format))
        add("marginLeft", marginLeft.map(Self.format))
        add("marginRight", marginRight.map(Self.format))
        add("preferCssPageSize", preferCssPageSize.map(Self.format))
        add("printBackground", printBackground.map(Self.format))
        add("omitBackground", omitBackground.map(Self.format))
        add("landscape", landscape.map(Self.format))
        add("scale", scale.map(Self.format))
        add("singlePage", singlePage.map(Self.format))
        add("waitDelay", waitDelay.map { (seconds: Double) -> String in "\(Self.format(seconds))s" })
        add("waitForExpression", waitForExpression)

        return fields
    }

    /// Whole numbers without a fraction (`1`, `11`), everything else in Swift's shortest
    /// round-tripping form (`8.5`, `0.25`).
    static func format(_ value: Double) -> String {
        if value.isFinite, value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    static func format(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}
