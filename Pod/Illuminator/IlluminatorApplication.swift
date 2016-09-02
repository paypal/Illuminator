//
//  IlluminatorApplication.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

public protocol IlluminatorApplication: CustomStringConvertible {
    var testCase: XCTestCase { get }
    //var app: XCUIApplication { get }
    var label: String { get }
    typealias AbstractScreenKeyType
    subscript(index: AbstractScreenKeyType) -> IlluminatorScreen { get }
}

public extension IlluminatorApplication {
    var description: String {
        return "\(self.dynamicType) \(self.label)"
    }
    
    
}

// functor to help satisfy the protocol in a generic way
// basically dependency injection
public struct IlluminatorApplicationGeneric<T>: IlluminatorApplication {
    public let label: String
    public let testCase: XCTestCase
    
    // hold a reference to the internal function so we can work around it
    private let _map: (T) -> IlluminatorScreen
    
    // `T` is effectively a handle for `AbstractScreenKeyType` in the protocol
    init<P : IlluminatorApplication where P.AbstractScreenKeyType == T>(_ app : P) {
        _map = { (key: T) in app[key] }
        label = app.label
        testCase = app.testCase
    }
    
    public subscript (index: T) -> IlluminatorScreen {
        return _map(index)
    }
}

