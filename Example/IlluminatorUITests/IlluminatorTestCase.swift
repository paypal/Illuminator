//
//  IlluminatorBaseTest.swift
//  Illuminator
//
//  Created by Ian Katz on 1/26/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
//
//  IlluminatorUITests.swift
//  IlluminatorUITests
//
//  Created by Ian Katz on 2017/01/26.
//  Copyright © 2015 CocoaPods. All rights reserved.
//

import XCTest
@testable import Illuminator

class IlluminatorTestCase: XCTestCase, IlluminatorTestResultHandler {

    // implement IlluminatorTestResultHandler protocol
    typealias AbstractStateType = AppTestState
    func handleTestResult(progress: IlluminatorTestProgress<AbstractStateType>) -> (){

        switch progress {
        case .Failing(let state):
            print("Failing state was \(state)")
            // on failure, print out what was on the screen when things failed
            for line in IlluminatorElement.accessorDump("app", appDebugDescription: app.debugDescription) {
                print(line)
            }
            print("(set breakpoint here")
        case .Flagging(let state):
            print("Flagging state was \(state)")
            // on failure, print out what was on the screen when things failed
            for line in IlluminatorElement.accessorDump("app", appDebugDescription: app.debugDescription) {
                print(line)
            }
            print("(set breakpoint here)")
        default:
            () // do nothing, fall back on default implementation of finish()
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

    
}
