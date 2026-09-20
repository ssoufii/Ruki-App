//
//  RukiUITests.swift
//  RukiUITests
//
//  Created by Salim Soufi on 2026-09-19.
//

import XCTest

/// L6 smoke suite (M1 completion checklist, docs/M1-PLAYBOOK.md §5): a single
/// run through onboarding -> Today -> check-in -> history on a fresh
/// Simulator install, using the app's own DEBUG clock-jump tools (T3) to land
/// on a guaranteed-open prayer window rather than depending on the Simulator's
/// wall-clock time, which would make this flaky depending on when CI runs.
///
/// Every step waits on `waitForExistence(timeout:)` rather than a fixed
/// sleep — SwiftUI sheet transitions and the (fast, synchronous)
/// `PlaceholderCameraProvider` capture are quick but not instant.
final class RukiUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Called at the top of every test rather than from `setUpWithError()`:
    /// XCTestCase's setUp methods are nonisolated, so Xcode 26 rejects both an
    /// `@MainActor` override and capturing `self` into a main-actor closure, while
    /// `XCUIApplication` and `continueAfterFailure` are main-actor. Each test is
    /// already `@MainActor`, so launching from here needs no isolation workaround.
    @MainActor
    private func launchApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testOnboardingThroughCheckInAndHistory() throws {
        launchApp()
        completeOnboarding()
        jumpDebugClock(to: "Dhuhr just began")
        checkIn(prayer: "Dhuhr")
        openHistory()
    }

    // MARK: Onboarding

    /// Madhab -> notification permission ("Not now", so no system alert to
    /// dismiss) -> intention -> add friends ("Skip for now") -- the one path
    /// that fully completes onboarding in M1 (RUKI-012).
    @MainActor
    private func completeOnboarding() {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10), "Madhab selection screen did not appear")
        continueButton.tap()

        let notNowButton = app.buttons["Not now"]
        XCTAssertTrue(notNowButton.waitForExistence(timeout: 5), "Notification permission screen did not appear")
        notNowButton.tap()

        let beginButton = app.buttons["I showed up. Let's begin."]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 5), "Intention screen did not appear")
        beginButton.tap()

        let skipButton = app.buttons["Skip for now"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "Add-friends screen did not appear")
        skipButton.tap()

        XCTAssertTrue(
            app.buttons["Settings"].waitForExistence(timeout: 5),
            "Today screen did not appear after onboarding"
        )
    }

    // MARK: Today / Settings

    /// Opens Settings, taps the named `DebugClockScenario` (DEBUG-only, T3),
    /// and dismisses back to Today. `SettingsView` has no toolbar close
    /// button (it's a bare `.sheet`), so this swipes down to dismiss.
    @MainActor
    private func jumpDebugClock(to scenarioLabel: String) {
        app.buttons["Settings"].tap()

        let scenarioButton = app.buttons[scenarioLabel]
        XCTAssertTrue(scenarioButton.waitForExistence(timeout: 5), "Debug clock scenario '\(scenarioLabel)' not found")
        scenarioButton.tap()

        app.swipeDown()
    }

    // MARK: Check-in

    /// Affirm -> capture (automatic, `PlaceholderCameraProvider` on the
    /// Simulator) -> post, then back on Today.
    @MainActor
    private func checkIn(prayer: String) {
        let checkInButton = app.buttons["Check in for \(prayer)"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 10), "No open check-in card for \(prayer)")
        checkInButton.tap()

        let affirmButton = app.buttons["I've prayed"]
        XCTAssertTrue(affirmButton.waitForExistence(timeout: 5), "Affirm step did not appear")
        affirmButton.tap()

        let postButton = app.buttons["Post"]
        XCTAssertTrue(postButton.waitForExistence(timeout: 10), "Review step did not appear after capture")
        postButton.tap()

        XCTAssertTrue(
            app.staticTexts["Checked in."].waitForExistence(timeout: 5),
            "Posted confirmation did not appear"
        )
    }

    // MARK: History

    @MainActor
    private func openHistory() {
        let historyButton = app.buttons["History"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5), "History button not found on Today")
        historyButton.tap()

        XCTAssertTrue(
            app.navigationBars["History"].waitForExistence(timeout: 5),
            "History screen did not appear"
        )
    }

    /// L6 (docs/M1-PLAYBOOK.md §5): a separate test from the flow smoke test
    /// above, so a real accessibility finding fails only this one rather than
    /// masking whether the flow itself still works.
    @MainActor
    func testAccessibilityAuditOnOnboardingAndToday() throws {
        launchApp()
        try app.performAccessibilityAudit()
        completeOnboarding()
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
