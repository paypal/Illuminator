//
//  IlluminatorUITests.swift
//  IlluminatorUITests
//
//  Created by Erceg, Boris on 16/10/15.
//  Copyright © 2015 CocoaPods. All rights reserved.
//

import XCTest
import Illuminator
import IlluminatorBridge

class IlluminatorUITests: XCTaggedTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_basicWithoutIlluminator() {
        
        let app = XCUIApplication()
        let textField = app.otherElements.containingType(.Button, identifier:"Button").childrenMatchingType(.TextField).element
        
        textField.tap()
        textField.typeText("test")
        
        XCTAssertEqual(textField.value as? String, "test")
        
    }
    
    func test_basicWithIlluminator() {
        
        let app = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))
        
        let myExampleText = "test123"
        
        initialState
            .apply(app.home.enterText(myExampleText))
            .apply(app.home.verifyText(myExampleText))
        .finish()
    }
    

}
