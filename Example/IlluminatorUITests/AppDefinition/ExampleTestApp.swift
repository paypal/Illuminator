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


// In this example, we just use a simple (named) boolean flag.
// For more information on what this is for, see the IlluminatorAction class description
struct AppTestState: CustomStringConvertible {
    var didSomething: Bool
    var description: String {
        get { return "\(didSomething)" }
    }
}

// The basic structure; this is a minimum implementation
struct ExampleTestApp: IlluminatorApplication {
    let label: String = "ExampleApp"
    let testCaseWrapper: IlluminatorTestcaseWrapper
    
    init(testCase t: XCTestCase) {
        testCaseWrapper = IlluminatorTestcaseWrapper(testCase: t)
    }

    // all screens are defined as read-only variables to save boilerplate code in the test definitions
    var home: HomeScreen {
        get {
            return HomeScreen(testCaseWrapper: testCaseWrapper)
        }
    }
    
}


