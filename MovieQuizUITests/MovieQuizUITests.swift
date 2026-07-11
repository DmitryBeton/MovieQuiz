//
//  MovieQuizUITests.swift
//  MovieQuizUITests
//
//  Created by Дмитрий Чалов on 27.07.2025.
//

import XCTest

@MainActor
final class MovieQuizUITests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    nonisolated(unsafe) var app: XCUIApplication!
    
    nonisolated override func setUpWithError() throws {
        try super.setUpWithError()

        app = MainActor.assumeIsolated {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launch()
            return app
        }

        // это специальная настройка для тестов: если один тест не прошёл,
        // то следующие тесты запускаться не будут; и правда, зачем ждать?
        continueAfterFailure = false
    }

    nonisolated override func tearDownWithError() throws {
        try super.tearDownWithError()

        let app = app
        MainActor.assumeIsolated {
            app?.terminate()
        }
        self.app = nil
    }
    
    func testYesButton() {
        let indexLabel = app.staticTexts["Index"]
        let yesButton = app.buttons["Yes"]

        waitForReadyQuestion(number: 1)
        app.buttons["Yes"].tap()

        waitForLabel(indexLabel, toEqual: "2/10")
        XCTAssertEqual(indexLabel.label, "2/10")
        XCTAssertTrue(yesButton.isEnabled)
    }
    
    func testNoButton() {
        let indexLabel = app.staticTexts["Index"]
        let noButton = app.buttons["No"]

        waitForReadyQuestion(number: 1)
        app.buttons["No"].tap()

        waitForLabel(indexLabel, toEqual: "2/10")
        XCTAssertEqual(indexLabel.label, "2/10")
        XCTAssertTrue(noButton.isEnabled)
    }
    
    func testGameFinish() {
        for questionNumber in 1...10 {
            waitForReadyQuestion(number: questionNumber)
            app.buttons["No"].tap()
        }

        let alert = app.alerts["Этот раунд окончен!"]

        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertEqual(alert.label, "Этот раунд окончен!")
        XCTAssertEqual(alert.buttons.firstMatch.label, "Сыграть ещё раз")
    }
    
    func testAlertDismiss() {
        for questionNumber in 1...10 {
            waitForReadyQuestion(number: questionNumber)
            app.buttons["No"].tap()
        }

        let alert = app.alerts["Этот раунд окончен!"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons.firstMatch.tap()

        let indexLabel = app.staticTexts["Index"]

        waitForNonExistence(alert)
        waitForReadyQuestion(number: 1)
        XCTAssertEqual(indexLabel.label, "1/10")
    }

    private func waitForReadyQuestion(number: Int) {
        let indexLabel = app.staticTexts["Index"]
        let yesButton = app.buttons["Yes"]
        let noButton = app.buttons["No"]

        if number == 1 {
            XCTAssertTrue(indexLabel.waitForExistence(timeout: 2))
            waitForEnabled(yesButton)
        } else {
            waitForLabel(indexLabel, toEqual: "\(number)/10")
        }

        XCTAssertEqual(indexLabel.label, "\(number)/10")
        XCTAssertTrue(yesButton.isEnabled)
        XCTAssertTrue(noButton.isEnabled)
    }

    private func waitForLabel(_ element: XCUIElement, toEqual label: String) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed)
    }

    private func waitForEnabled(_ element: XCUIElement) {
        let predicate = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed)
    }

    private func waitForNonExistence(_ element: XCUIElement) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed)
    }
}
