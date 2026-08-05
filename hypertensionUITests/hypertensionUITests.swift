//
//  hypertensionUITests.swift
//  hypertensionUITests
//
//  Created by Haoyu Zuo on 2026/6/27.
//

import XCTest

final class hypertensionUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testResponsiveTodayAndAdjustmentLayouts() throws {
        let app = XCUIApplication()
        app.launch()

        let debugPreviewButton = app.buttons["auth.debugPreviewButton"]
        XCTAssertTrue(debugPreviewButton.waitForExistence(timeout: 8))
        debugPreviewButton.tap()

        let morningBloodPressureTitle = app.staticTexts["早晨血压测量"]
        XCTAssertTrue(morningBloodPressureTitle.waitForExistence(timeout: 8))

        let todayScreenshot = XCTAttachment(screenshot: app.screenshot())
        todayScreenshot.name = "iPhone 14 - 今日行动窄屏布局"
        todayScreenshot.lifetime = .keepAlways
        add(todayScreenshot)

        let adjustmentTab = app.tabBars.buttons["行动调整"]
        XCTAssertTrue(adjustmentTab.waitForExistence(timeout: 5))
        adjustmentTab.tap()

        let adjustmentButton = app.buttons["调整"].firstMatch
        XCTAssertTrue(adjustmentButton.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(adjustmentButton.frame.width, adjustmentButton.frame.height)
        XCTAssertGreaterThan(adjustmentButton.frame.width, 52)

        let adjustableBadge = app.staticTexts["可调整"].firstMatch
        XCTAssertTrue(adjustableBadge.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(adjustableBadge.frame.width, adjustableBadge.frame.height)

        let adjustmentScreenshot = XCTAttachment(screenshot: app.screenshot())
        adjustmentScreenshot.name = "iPhone 14 - 行动调整窄屏布局"
        adjustmentScreenshot.lifetime = .keepAlways
        add(adjustmentScreenshot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
