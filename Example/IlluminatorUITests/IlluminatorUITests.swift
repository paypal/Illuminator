//
//  IlluminatorUITests.swift
//  IlluminatorUITests
//
//  Created by Erceg, Boris on 16/10/15.
//  Copyright © 2015 CocoaPods. All rights reserved.
//

import XCTest
@testable import Illuminator
import IlluminatorBridge

class IlluminatorUITests: XCTestCase, IlluminatorTestResultHandler {
    
    // implement IlluminatorTestResultHandler protocol
    typealias AbstractStateType = AppTestState
    func handleTestResult(isPass: Bool, isFail: Bool, state: AbstractStateType?, errorMessages: [String]) -> (){
        // on failure, print out what was on the screen when things failed
        if isFail {
            for line in IlluminatorElement.accessorDump("app", appDebugDescription: app.debugDescription) {
                print(line)
            }
        }
        
        if isPass {
            print("THE RESULT WAS A PASS! but generally we don't do anything for passing tests")
        }
    }
    
    var app: XCUIApplication!

    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launch()
        
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_basicWithoutIlluminator() {
        
        let textField = app.otherElements.containingType(.Button, identifier:"Button").childrenMatchingType(.TextField).element
        
        textField.tap()
        textField.typeText("test")
        
        XCTAssertEqual(textField.value as? String, "test")
        
    }
    
    func test_basicWithIlluminator() {
        
        let interface = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))
        
        let myExampleText = "test123"
        
        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish()
    }
    
    func test_basicWithIlluminatorAndHandler() {
        
        let interface = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))
        
        let myExampleText = "test123"
        
        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish(self)
    }
    

}
