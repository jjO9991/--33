import XCTest

final class QHUITests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["契合"].waitForExistence(timeout: 5))
    }
}
