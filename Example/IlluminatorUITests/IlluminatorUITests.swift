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
    

    func test_basicWithIlluminatorCompositeAction() {
        initialState
            .apply(interface.home.enterAndVerifyText("test123"))
            .finish(self)
    }
    
    func test_basicWithIlluminatorAndHandlerProtocol() {
        let myExampleText = "test123"

        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish(self)
    }
    
    func test_basicWithIlluminatorAndHandlerClosure() {
        let myExampleText = "test123"

        initialState
            .apply(interface.home.enterText(myExampleText))
            .apply(interface.home.verifyText(myExampleText))
            .finish(self.handleTestResult)
    }
    

}
