//
//  IlluminatorScreen.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
import KIF

public protocol IlluminatorScreen: CustomStringConvertible {
    var testCase: XCTestCase { get }
    var label: String { get }
    var isActive: Bool { get }
    func becomesActive() throws
}

public extension IlluminatorScreen {

    var description: String {
        return "\(self.dynamicType) \(self.label)"
    }
    

    
    // shortcut function to make an action tied to this screen that either reads or writes the test state
    func makeAction<T>(label l: String = __FUNCTION__, task: (T) throws -> T) -> IlluminatorActionGeneric<T> {
        return IlluminatorActionGeneric(label: l, testCase: self.testCase, screen: self, task: task)
    }
    
    // shortcut function to make an action tied to this screen that neither reads nor writes the test state
    func makeAction<T>(label l: String = __FUNCTION__, task: () throws -> ()) -> IlluminatorActionGeneric<T> {
        return makeAction(label: l) { (state: T) in
            try task()
            return state
        }
    }
    
    func interface() -> IlluminatorInterface {
        return IlluminatorInterface()
    }
    
}

// a screen that is always available (more like a shake action)
public class IlluminatorSimpleScreen<T>: IlluminatorScreen {
    public let testCase: XCTestCase
    public let label: String
    
    public init (label labelVal: String, testCase t: XCTestCase) {
        testCase = t
        label = labelVal
    }
    
  
    // By default, we assume that the screen is always active.  This should be overridden with a more realistic measurement
    public var isActive: Bool {
        return true
    }
    
    // Since the screen is always active, we don't need to waste time
    public func becomesActive() throws {
        return
    }
    
    public func verifyIsActive() -> IlluminatorActionGeneric<T> {
        return makeAction(label: __FUNCTION__) { $0 }
    }
    
    public func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorSimpleScreen<T>(label: "null screen", testCase: self.testCase)
        return IlluminatorActionGeneric(label: __FUNCTION__, testCase: self.testCase, screen: nullScreen) { state in
            throw IlluminatorExceptions.IncorrectScreen(message: "IlluminatorSimpleScreen instances are always active")
        }
    }
}

// a "normal" screen -- one that may take a moment of animation to appear
public class IlluminatorDelayedScreen<T>: IlluminatorSimpleScreen<T> {
    let screenTimeout: Double
    var nextTimeout: Double // For setting temporarily
    
    public init (label labelVal: String, testCase t: XCTestCase, screenTimeout s: Double) {
        screenTimeout = s
        nextTimeout = s
        super.init(label: labelVal, testCase: t)
    }
    
    
    // By default, we assume that the screen
    override public func becomesActive() throws {
        defer { nextTimeout = screenTimeout }  // reset the timeout after we run
        try waitForResult(nextTimeout, desired: true, what: "[\(self) isActive]", getResult: { self.isActive })
    }
    
    override public func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorSimpleScreen<T>(label: "null screen", testCase: self.testCase)
        return IlluminatorActionGeneric(label: __FUNCTION__, testCase: self.testCase, screen: nullScreen) { state in
            var stillActive: Bool
            do {
                try waitForResult(self.nextTimeout, desired: false, what: "[\(self) isActive]", getResult: { self.isActive })
                stillActive = false
            } catch IlluminatorExceptions.IncorrectScreen {
                stillActive = true
            }
            
            if stillActive {
                throw IlluminatorExceptions.IncorrectScreen(message: "\(self) failed to become inactive")
            }
            return state
        }
    }
}

// a screen whose appearance is linked to the (dis)appearance of a transient dialog (like a spinner)
public class IlluminatorScreenWithTransient<T>: IlluminatorSimpleScreen<T> {
    let screenTimeoutSoft: Double   // how long we'd wait if we didn't see the transient
    let screenTimeoutHard: Double   // how long we'd wait if we DID see the transient
    
    var nextTimeoutSoft: Double     // Sometimes we may want to adjust the timeouts temporarily
    var nextTimeoutHard: Double
    
    
    public init (testCase: XCTestCase,
          label: String,
          screenTimeoutSoft timeoutSoft: Double,
          screenTimeoutHard timeoutHard: Double) {
        screenTimeoutSoft = timeoutSoft
        screenTimeoutHard = timeoutHard
        nextTimeoutSoft = screenTimeoutSoft
        nextTimeoutHard = screenTimeoutHard
            super.init(label: label, testCase: testCase)
    }
    
    // To be overridden by the extender of the class
    public var transientIsActive: Bool {
        return false;
    }
    
    override public func becomesActive() throws {
        defer {
            nextTimeoutSoft = screenTimeoutSoft
            nextTimeoutHard = screenTimeoutHard
        }
        
        let hardTime = NSDate()
        var softTime = NSDate()
        repeat {
            if transientIsActive {
                softTime = NSDate()
            } else if isActive {
                return
            }
        } while hardTime.timeIntervalSinceNow < nextTimeoutHard && softTime.timeIntervalSinceNow < nextTimeoutSoft

        let msg = "[\(self) becomesActive] failed "
        throw IlluminatorExceptions.IncorrectScreen(
            message: msg + ((hardTime.timeIntervalSinceNow > nextTimeoutHard) ? "hard" : "soft") + " timeout")
    }
    
    override public func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorSimpleScreen<T>(label: "null screen", testCase: self.testCase)
        return IlluminatorActionGeneric(label: __FUNCTION__, testCase: self.testCase, screen: nullScreen) { state in

            let hardTime = NSDate()
            var softTime = NSDate()
            repeat {
                if self.transientIsActive {
                    softTime = NSDate()
                } else if !self.isActive {
                    return state
                }
            } while hardTime.timeIntervalSinceNow < self.nextTimeoutHard && softTime.timeIntervalSinceNow < self.nextTimeoutSoft
            
            
            if self.isActive {
                throw IlluminatorExceptions.IncorrectScreen(message: "\(self) failed to become inactive")
            }
            return state
        }
    }
}
