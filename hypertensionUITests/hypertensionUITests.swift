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

        let morningBloodPressureCard = app.buttons["today.bp.morning"].firstMatch
        for _ in 0..<4 where !morningBloodPressureCard.exists {
            app.swipeUp()
        }
        XCTAssertTrue(morningBloodPressureCard.waitForExistence(timeout: 8))
        XCTAssertEqual(morningBloodPressureCard.label, "早晨血压测量")

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
    func testMealSheetCloseButtonWorksForBreakfastLunchAndDinner() throws {
        let app = XCUIApplication()
        app.launch()

        let debugPreviewButton = app.buttons["auth.debugPreviewButton"]
        XCTAssertTrue(debugPreviewButton.waitForExistence(timeout: 8))
        debugPreviewButton.tap()

        let closeButton = app.buttons["meal.closeButton"]
        for meal in ["breakfast", "lunch", "dinner"] {
            let mealCard = app.buttons.matching(identifier: "today.meal.\(meal)").firstMatch
            XCTAssertTrue(scrollUntilHittable(mealCard, in: app), "\(meal) card should be tappable")
            mealCard.tap()

            XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
            XCTAssertTrue(closeButton.isHittable)
            closeButton.tap()
            XCTAssertFalse(closeButton.waitForExistence(timeout: 2))
        }
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<10 {
            if element.exists && element.isHittable {
                return true
            }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    func testLowBarrierExerciseGenerationUsesOneProgressiveModule() throws {
        let app = XCUIApplication()
        app.launch()

        let debugPreviewButton = app.buttons["auth.debugPreviewButton"]
        XCTAssertTrue(debugPreviewButton.waitForExistence(timeout: 8))
        debugPreviewButton.tap()

        let generationTab = app.tabBars.buttons["行动生成"]
        XCTAssertTrue(generationTab.waitForExistence(timeout: 5))
        generationTab.tap()

        let module = app.otherElements["low-barrier-exercise-generation"]
        XCTAssertTrue(module.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["生成低门槛运动"].exists)
        XCTAssertTrue(app.staticTexts["选择场景"].exists)
        XCTAssertTrue(app.staticTexts["选择当前状态"].exists)

        app.staticTexts["私人室内"].firstMatch.tap()
        app.staticTexts["精力低"].firstMatch.tap()
        app.staticTexts["久坐后"].firstMatch.tap()

        let generateButton = app.buttons["生成今日运动"]
        for _ in 0..<8 where !generateButton.exists {
            app.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["选择推荐运动"].exists)
        XCTAssertTrue(app.staticTexts["设置运动时间"].exists)
        XCTAssertTrue(app.staticTexts["开始时间"].exists)
        XCTAssertTrue(app.staticTexts["结束时间"].exists)
        XCTAssertFalse(app.staticTexts["运动时长"].exists)
        XCTAssertFalse(app.staticTexts["预约开始时间"].exists)
        XCTAssertTrue(generateButton.exists)
    }

    @MainActor
    func testBloodPressureUsesLatestReadingCopyAndCameraHeaderHasNoAvatar() throws {
        let app = XCUIApplication()
        app.launch()

        let debugPreviewButton = app.buttons["auth.debugPreviewButton"]
        XCTAssertTrue(debugPreviewButton.waitForExistence(timeout: 8))
        debugPreviewButton.tap()

        let bloodPressureTab = app.tabBars.buttons["血压读数"]
        XCTAssertTrue(bloodPressureTab.waitForExistence(timeout: 5))
        bloodPressureTab.tap()

        XCTAssertTrue(app.staticTexts["最近的读数"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["今天的读数"].exists)

        let uploadButton = app.buttons["拍照上传读数"]
        XCTAssertTrue(uploadButton.waitForExistence(timeout: 5))
        uploadButton.tap()

        XCTAssertTrue(app.staticTexts["拍照上传"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["小宁"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
