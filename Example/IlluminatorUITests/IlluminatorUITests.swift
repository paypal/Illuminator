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

class IlluminatorUITests: IlluminatorTestCase {
    

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
            .finish(self)
    }

    func test_basicWithIlluminatorCompositeAction() {

        let interface = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))

        let myExampleText = "test123"

        initialState
            .apply(interface.home.enterAndVerifyText(myExampleText))
            .finish(self)
    }
    
    func test_basicWithIlluminatorAndHandlerProtocol() {

        let interface = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))

        let myExampleText = "test123"

        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish(self)
    }
    
    func test_basicWithIlluminatorAndHandlerClosure() {

        let interface = ExampleTestApp(testCase: self)
        let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))

        let myExampleText = "test123"

        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish(self.handleTestResult)
    }
    

}
