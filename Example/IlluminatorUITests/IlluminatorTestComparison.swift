//
//  IlluminatorUITests.swift
//  IlluminatorUITests
//
//  Created by Ian Katz on 2017/01/27.
//  Copyright © 2015 CocoaPods. All rights reserved.
//

import XCTest
@testable import Illuminator

class IlluminatorTestComparison: XCTestCase {

    var app: XCUIApplication!


    override func setUp() {
        super.setUp()

        app = XCUIApplication()
        app.launch()
    }

    // An example of how a very basic test looks without Illuminator
    func test_basicWithoutIlluminator() {

        let textField = app.otherElements.containingType(.Button, identifier:"Button").childrenMatchingType(.TextField).element

        // enter text
        textField.tap()
        textField.typeText("test")

        // verify text
        XCTAssertEqual(textField.value as? String, "test")

    }

    // With Illuminator, the test steps are clearer
    func test_basicWithIlluminator() {
        // boilerplate setup code that is typically placed in setUp()
        // shown here for overall clarity
        let interface = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))

        // Factor out data that will be used in multiple places
        let myExampleText = "test123"

        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish() { progress in
                print("This will be the last code to execute before the test passes or fails")
                print("This is a good opportunity to react to the current progress: \(progress)")
        }
    }


    
}
