//
//  IlluminatorAction.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

/**
    Illuminator Actions are discrete chunks of UI interaction that can be scripted into more sophisticated tests.
 
    Actions (part of screens, which are part of the app) don't contain state; they simply act, and either succeed or fail in doing so.  In the rare case where stateful information is required by an action, Illuminator provides the AbstractStateType (essentially, a generic) to contain and convey this information to subsequent actions.

    Actions can both read and write the test state object, or ignore it completely.  In the vast majority of cases, they will ignore it; the test writer should be able to supply nearly all expected values for the test to verify.  One notable exception would be functions that depend on a random seed -- the seed would be part of the test state.  Another would be a test of a stopwatch function, in which the timestamp of taapping the "start" button might be saved in order to properly verify the correctness of the elapsed time.

    Actions rely on a test state, whose type is generic -- specific to the application.  This state supplies information that might be relevant to the UI action (which is otherwise stateless).

    - they have a function that takes state (absctract type) and returns state, throws
    - they are created from blocks within the screen defintion -- they contain a ref to the screen
    - they need a reference to an IlluminatorTestCaseWrapper to be able to push/pop continueAfterFailure
*/
public protocol IlluminatorAction: CustomStringConvertible {
    var label: String { get }
    var testCaseWrapper: IlluminatorTestcaseWrapper { get }
    var screen: IlluminatorScreen? { get }
    var file: StaticString { get }
    var line: UInt { get }
    associatedtype AbstractStateType
    func task(_ state: AbstractStateType) throws -> AbstractStateType
}

public extension IlluminatorAction {
    
    /**
        CustomStringConvertible implementation
        - Returns: The action's name (label)
     */
    var description: String {
        get {
            return label
        }
    }

    /**
        A shortcut accessor to the screen's test case, through the wrapper
        - Returns: The screen's underlying test case
    */
    var testCase: XCTestCase {
        get {
            return testCaseWrapper.testCase
        }
    }
}

/**
    This struct is a cheap hack to get a generic protocol

    https://milen.me/writings/swift-generic-protocols/
 */
public struct IlluminatorActionGeneric<T>: IlluminatorAction {
    public let label: String
    public let testCaseWrapper: IlluminatorTestcaseWrapper
    public let screen: IlluminatorScreen?
    public let file: StaticString
    public let line: UInt
    
    fileprivate let _task: (T) throws -> T
    
    init<P : IlluminatorAction> (file fi: StaticString, line li: UInt, action dep: P) where P.AbstractStateType == T {
        label = dep.label
        testCaseWrapper = dep.testCaseWrapper
        screen = dep.screen
        file = fi
        line = li
        _task = dep.task
    }
    
    init(label l: String, testCaseWrapper t: IlluminatorTestcaseWrapper, screen s: IlluminatorScreen?, file fi: StaticString, line li: UInt, task: @escaping (T) throws -> T) {
        label = l
        testCaseWrapper = t
        screen = s
        file = fi
        line = li
        _task = task
    }
    
    public func task(_ state: T) throws -> T {
        return try _task(state)
    }
    
}
