import XCTest
@testable import GotenbergKit

final class ChromiumPageOptionsTests: XCTestCase {
    private func pairs(_ options: ChromiumPageOptions) -> [String] {
        options.formFields.map { (field: (name: String, value: String)) -> String in "\(field.name)=\(field.value)" }
    }

    func testEmptyOptionsSendNothing() {
        XCTAssertTrue(ChromiumPageOptions().formFields.isEmpty)
    }

    func testOnlySetFieldsAreSentInDeclarationOrder() {
        let options: ChromiumPageOptions = ChromiumPageOptions(
            paperWidth: 8.5,
            paperHeight: 11,
            marginTop: 1,
            marginBottom: 1,
            marginLeft: 0.25,
            marginRight: 0.25,
            printBackground: true,
            landscape: false,
            waitDelay: 2
        )
        XCTAssertEqual(pairs(options), [
            "paperWidth=8.5",
            "paperHeight=11",
            "marginTop=1",
            "marginBottom=1",
            "marginLeft=0.25",
            "marginRight=0.25",
            "printBackground=true",
            "landscape=false",
            "waitDelay=2s",
        ])
    }

    func testEveryFieldInDeclarationOrder() {
        let options: ChromiumPageOptions = ChromiumPageOptions(
            paperWidth: 8.27,
            paperHeight: 11.7,
            marginTop: 0,
            marginBottom: 0.5,
            marginLeft: 0.75,
            marginRight: 1.5,
            preferCssPageSize: true,
            printBackground: false,
            omitBackground: true,
            landscape: true,
            scale: 0.9,
            singlePage: false,
            waitDelay: 0.5,
            waitForExpression: "window.status === 'ready'"
        )
        XCTAssertEqual(pairs(options), [
            "paperWidth=8.27",
            "paperHeight=11.7",
            "marginTop=0",
            "marginBottom=0.5",
            "marginLeft=0.75",
            "marginRight=1.5",
            "preferCssPageSize=true",
            "printBackground=false",
            "omitBackground=true",
            "landscape=true",
            "scale=0.9",
            "singlePage=false",
            "waitDelay=0.5s",
            "waitForExpression=window.status === 'ready'",
        ])
    }

    func testOnlyGotenbergEightAndNineFieldNamesAreEverSent() {
        let options: ChromiumPageOptions = ChromiumPageOptions(
            paperWidth: 1, paperHeight: 1, marginTop: 1, marginBottom: 1, marginLeft: 1, marginRight: 1,
            preferCssPageSize: true, printBackground: true, omitBackground: true, landscape: true,
            scale: 1, singlePage: true, waitDelay: 1, waitForExpression: "true"
        )
        let names: Set<String> = Set(options.formFields.map { (field: (name: String, value: String)) -> String in field.name })
        let allowed: Set<String> = [
            "paperWidth", "paperHeight", "marginTop", "marginBottom", "marginLeft", "marginRight",
            "preferCssPageSize", "printBackground", "omitBackground", "landscape", "scale",
            "singlePage", "waitDelay", "waitForExpression",
        ]
        XCTAssertEqual(names, allowed)
    }
}
