//
//  IlluminatorScreen.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


protocol IlluminatorScreen: CustomStringConvertible {
    var testCase: XCTestCase { get }
    var label: String { get }
    var isActive: Bool { get }
    func becomesActive() throws
}

extension IlluminatorScreen {

    var description: String {
        return "\(self.dynamicType) \(self.label)"
    }
    
    func makeAction<T>(label l: String, task: (T) throws -> T) -> IlluminatorActionGeneric<T> {
        return IlluminatorActionGeneric(label: l, testCase: self.testCase, screen: self, task: task)
    }
 
    internal func tester(file : String = __FILE__, _ line : Int = __LINE__) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self.testCase)
    }
    
    internal func system(file : String = __FILE__, _ line : Int = __LINE__) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self.testCase)
    }
    
}

class IlluminatorSimpleScreen: IlluminatorScreen {
    let testCase: XCTestCase
    let label: String
    
    init (label labelVal: String, testCase t: XCTestCase) {
        testCase = t
        label = labelVal
    }
    
  
    // By default, we assume that the screen is always active.  This should be overridden with a more realistic measurement
    var isActive: Bool {
        return true
    }
    
    // Since the screen is always active, we don't need to waste time
    func becomesActive() throws {
        return
    }
}



class IlluminatorDelayedScreen: IlluminatorSimpleScreen {
    let screenTimeout: Double
    var nextTimeout: Double // For setting temporarily
    
    init (label labelVal: String, testCase t: XCTestCase, screenTimeout s: Double) {
        screenTimeout = s
        nextTimeout = s
        super.init(label: labelVal, testCase: t)
    }
    
    
    // By default, we assume that the screen
    override func becomesActive() throws {
        defer { nextTimeout = screenTimeout }  // reset the timeout after we run
        try waitForResult(nextTimeout, desired: true, what: "[\(self) isActive]", getResult: { self.isActive })
    }
}

class IlluminatorScreenWithTransient: IlluminatorSimpleScreen {
    let screenTimeoutSoft: Double   // how long we'd wait if we didn't see the transient
    let screenTimeoutHard: Double   // how long we'd wait if we DID see the transient
    
    var nextTimeoutSoft: Double     // Sometimes we may want to adjust the timeouts temporarily
    var nextTimeoutHard: Double
    
    
    
    init (testCase: XCTestCase,
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
    var transientIsActive: Bool {
        return false;
    }
    
    override func becomesActive() throws {
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
}
