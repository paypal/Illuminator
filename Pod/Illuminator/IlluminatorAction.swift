//
//  IlluminatorAction.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

// - actions have a function that takes state (absctract type) and returns state, throws
// - actions are created from blocks within the screen defintion -- they contain a ref to the screen
// - They also need a reference to an IlluminatorTestCaseWrapper to be able to push/pop continueAfterFailure
public protocol IlluminatorAction: CustomStringConvertible {
    var label: String { get }
    var testCaseWrapper: IlluminatorTestcaseWrapper { get }
    var screen: IlluminatorScreen? { get }
    associatedtype AbstractStateType
    func task(state: AbstractStateType) throws -> AbstractStateType
}

public extension IlluminatorAction {
    
    var description: String {
        get {
            return label
        }
    }

    var testCase: XCTestCase {
        get {
            return testCaseWrapper.testCase
        }
    }
}


public struct IlluminatorActionGeneric<T>: IlluminatorAction {
    public let label: String
    public let testCaseWrapper: IlluminatorTestcaseWrapper
    public let screen: IlluminatorScreen?
    
    private let _task: (T) throws -> T
    
    init<P : IlluminatorAction where P.AbstractStateType == T> (action dep: P) {
        label = dep.label
        testCaseWrapper = dep.testCaseWrapper
        screen = dep.screen
        _task = dep.task
    }
    
    init(label l: String, testCaseWrapper t: IlluminatorTestcaseWrapper, screen s: IlluminatorScreen?, task: (T) throws -> T) {
        label = l
        testCaseWrapper = t
        screen = s
        _task = task
    }
    
    public func task(state: T) throws -> T {
        return try _task(state)
    }
    
}
