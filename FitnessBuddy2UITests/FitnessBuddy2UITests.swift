import XCTest

final class FitnessBuddy2UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStartWorkoutAndLogASet() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITNESS_BUDDY_UI_TEST_RESET"] = "1"
        app.launch()

        let start = app.buttons["start-workout-button"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()

        XCTAssertTrue(app.staticTexts["ACTIVE / SESSION"].waitForExistence(timeout: 5))
        let firstRIR = app.textFields["rir-field-1"]
        XCTAssertTrue(firstRIR.waitForExistence(timeout: 5))
        firstRIR.tap()
        firstRIR.typeText("2")

        let firstSet = app.buttons["complete-set-1"]
        XCTAssertTrue(firstSet.waitForExistence(timeout: 5))
        XCTAssertTrue(firstSet.isEnabled)
        firstSet.tap()
        XCTAssertTrue(app.staticTexts["REST / RECOVER"].waitForExistence(timeout: 3))

        app.buttons["close-workout-button"].tap()
        XCTAssertTrue(app.buttons["Discard workout"].waitForExistence(timeout: 3))
        app.buttons["Discard workout"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 4))
    }

    @MainActor
    func testInsightsTabShowsLocalTrainingSignals() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITNESS_BUDDY_UI_TEST_RESET"] = "1"
        app.launch()

        let insightsTab = tabButton("INSIGHTS", in: app)
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 8))
        insightsTab.tap()

        XCTAssertTrue(app.staticTexts["ON-DEVICE / LIVE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LOAD DECISIONS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PROGRAM LOGIC"].waitForExistence(timeout: 5))

        let longRange = app.buttons["LAST 28 DAYS"]
        XCTAssertTrue(longRange.waitForExistence(timeout: 3))
        longRange.tap()
        XCTAssertTrue(longRange.isSelected)
    }

    /// Produces the five launch screenshots used for the App Store listing.
    /// The flow relies only on accessibility labels/identifiers, so the same
    /// test can also be run against an iPad destination without coordinates or
    /// device-specific layout assumptions.
    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = seededScreenshotApp()
        app.launch()

        let startWorkout = app.buttons["start-workout-button"]
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 10))
        attachScreenshot(named: "AppStore_01_Today", from: app)

        let trainTab = tabButton("TRAIN", in: app)
        XCTAssertTrue(trainTab.waitForExistence(timeout: 5))
        trainTab.tap()
        XCTAssertTrue(app.staticTexts["CURRENT PROGRAM"].waitForExistence(timeout: 5))
        waitForTabAnimation()
        attachScreenshot(named: "AppStore_02_Train", from: app)

        let insightsTab = tabButton("INSIGHTS", in: app)
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 5))
        insightsTab.tap()
        XCTAssertTrue(app.staticTexts["ON-DEVICE / LIVE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LOAD DECISIONS"].waitForExistence(timeout: 5))
        waitForTabAnimation()
        attachScreenshot(named: "AppStore_03_Insights", from: app)

        let progressTab = tabButton("PROGRESS", in: app)
        XCTAssertTrue(progressTab.waitForExistence(timeout: 5))
        progressTab.tap()
        XCTAssertTrue(app.staticTexts["TRAINING LOAD"].waitForExistence(timeout: 5))
        waitForTabAnimation()
        attachScreenshot(named: "AppStore_04_Progress", from: app)

        let todayTab = tabButton("TODAY", in: app)
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 5))
        waitForTabAnimation()
        startWorkout.tap()
        XCTAssertTrue(app.staticTexts["ACTIVE / SESSION"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["rir-field-1"].waitForExistence(timeout: 5))
        attachScreenshot(named: "AppStore_05_ActiveWorkout", from: app)

        app.buttons["close-workout-button"].tap()
        XCTAssertTrue(app.buttons["Discard workout"].waitForExistence(timeout: 3))
        app.buttons["Discard workout"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchEnvironment["FITNESS_BUDDY_UI_TEST_RESET"] = "1"
            app.launch()
        }
    }

    @MainActor
    private func seededScreenshotApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FITNESS_BUDDY_UI_TEST_RESET"] = "1"
        app.launchEnvironment["FITNESS_BUDDY_APP_STORE_SCREENSHOTS"] = "1"
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // Shadow any persisted profile with a non-Data argument value so
            // UserData takes its deterministic legacy/UI-test seed path.
            "-fitnessBuddy.profile.v3", "APP_STORE_SCREENSHOT_SEED",
            "-userName", "Alex Morgan",
            "-userAge", "29",
            "-userHeight", "5 ft 10 in",
            "-userWeight", "170",
            "-userExperienceLevel", "Intermediate",
        ]
        return app
    }

    @MainActor
    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tabButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        // iPad's floating tab bar can expose both its item and its nested view
        // as buttons with the same label. Selecting the first match keeps the
        // screenshot flow stable on both iPhone and iPad.
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func waitForTabAnimation() {
        // Content becomes hittable before the floating liquid-glass tab bar
        // finishes expanding on iPad. Capture only its settled presentation.
        Thread.sleep(forTimeInterval: 3)
    }
}
