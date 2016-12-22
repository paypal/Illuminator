//
//  ExampleTestApp.swift
//  Illuminator
//
//  Created by Ian Katz on 12/5/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation

import XCTest
import Illuminator


// Actions (part of screens, which are part of the app) don't contain state.
// The current state of the app is passed to them -- for example:
// - whether a one-time alert has been dismissed might affect the expected 
//   value or behavior of an action.
// - knowing that a mock network request has been asked to fail
//
// Actions can both read and write the state object, or ignore it completely
//
// In this example, we just use a simple (named) boolean flag.
struct AppTestState: CustomStringConvertible {
    var didSomething: Bool
    var description: String {
        get { return "\(didSomething)" }
    }
}


struct ExampleTestApp: IlluminatorApplication {
    let label: String = "ExampleApp"
    let testCaseWrapper: IlluminatorTestcaseWrapper
    
    init(testCase t: XCTestCase) {
        testCaseWrapper = IlluminatorTestcaseWrapper(testCase: t)
    }
    
    var home: HomeScreen {
        get {
            return HomeScreen(testCaseWrapper: testCaseWrapper)
        }
    }
    
}


