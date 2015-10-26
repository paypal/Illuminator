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
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample_bug() {
        
        let app = XCUIApplication()
        let button = app.buttons["Button"]
        let textField = app.otherElements.containingType(.Button, identifier:"Button").childrenMatchingType(.TextField).element
        
        textField.tap()
        textField.typeText("test")
        button.tap()
        
        XCTAssertEqual(textField.value as? String, "testv")
        
    }
    
    func testExceptionThrowing() {
        
        let exception = NSException(name: "exception", reason: nil, userInfo: nil)
        tryBlock({
                throwException(exception)
            }, catchBlock: { newException in
                XCTAssert(newException == exception)
            }, finally:  {
        })
        
        
    }
    
    func testExample_bridge() {
        
        let app = XCUIApplication()
        
        XCTUIBridge.sendNotification("showAlert")
        
        let alert = app.alerts["Alert"]
        alert.collectionViews.buttons["OK"].tap()
    }
}
