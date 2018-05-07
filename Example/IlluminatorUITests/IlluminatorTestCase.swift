//
//  IlluminatorTestCase.swift
//  IlluminatorUITests
//
//  Created by Ian Katz on 2017/01/26.
//  Copyright © 2015 CocoaPods. All rights reserved.
//

import XCTest
@testable import Illuminator

class IlluminatorTestCase: XCTestCase, IlluminatorTestResultHandler {

    // Implement IlluminatorTestResultHandler protocol.
    // This allows the base class to provide standardzied error handling
    // across all your test classes by ending tests with `.finish(self)`
    // as opposed to supplying a closure each time
    typealias AbstractStateType = AppTestState
    func handleTestResult(_ progress: IlluminatorTestProgress<AbstractStateType>) -> (){

        switch progress {
        case .failing(let state):
            print("Failing state was \(state)")
            // on failure, print out what was on the screen when things failed
            for line in IlluminatorElement.accessorDump("app", appDebugDescription: app.debugDescription) {
                print(line)
            }
            print("(set breakpoint here")
        case .flagging(let state):
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
    var interface: ExampleTestApp!
    var initialState: IlluminatorTestProgress<AppTestState>!

    override func setUp() {
        super.setUp()

        app = XCUIApplication()
        app.launch()

        interface = ExampleTestApp(testCase: self)
        initialState = IlluminatorTestProgress<AppTestState>.passing(AppTestState(didSomething: false))
    }


}
