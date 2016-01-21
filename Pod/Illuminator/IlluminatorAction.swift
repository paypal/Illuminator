//
//  IlluminatorAction.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

// actions have a function that takes state (absctract type) and returns state, throws
// actions are created from blocks within the screen defintion -- they contain a ref to the screen
protocol IlluminatorAction: CustomStringConvertible {
    var label: String { get }
    var testCase: XCTestCase { get }
    var screen: IlluminatorScreen? { get }
    typealias AbstractStateType
    func task(state: AbstractStateType) throws -> AbstractStateType
}

extension IlluminatorAction {
    var description: String {
        get {
            return "\(self.dynamicType) \(self.label)"
        }
    }
    
    internal func tester(file : String = __FILE__, _ line : Int = __LINE__) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self.testCase)
    }
    
    internal func system(file : String = __FILE__, _ line : Int = __LINE__) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self.testCase)
    }
}


struct IlluminatorActionGeneric<T>: IlluminatorAction {
    let label: String
    let testCase: XCTestCase
    let screen: IlluminatorScreen?
    
    private let _task: (T) throws -> T
    
    init<P : IlluminatorAction where P.AbstractStateType == T> (action dep: P) {
        label = dep.label
        testCase = dep.testCase
        screen = dep.screen
        _task = dep.task
    }
    
    init(label l: String, testCase t: XCTestCase, screen s: IlluminatorScreen?, task: (T) throws -> T) {
        label = l
        testCase = t
        screen = s
        _task = task
    }
    
    func task(state: T) throws -> T {
        return try _task(state)
    }
    
}


