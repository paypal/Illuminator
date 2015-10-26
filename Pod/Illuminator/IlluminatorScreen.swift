//
//  IlluminatorScreen.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


protocol IlluminatorScreen: CustomStringConvertible {
    var parent: IlluminatorApplication { get }
    var label: String { get }
    var isActive: Bool { get }
    func becomesActive() throws
}

extension IlluminatorScreen {

    var description: String {
        get {
            return "\(self.parent.label) screen \(self.label)"
        }
    }
    
    // for convenience
    var app: XCUIApplication {
        get {
            return self.parent.app
        }
    }
}

class IlluminatorSimpleScreen: IlluminatorScreen {
    let parent: IlluminatorApplication
    let label: String
    
    init (containingApplication: IlluminatorApplication, label labelVal: String) {
        parent = containingApplication
        label = labelVal
    }
    
  
    // By default, we assume that the screen is always active.  This should be overridden with a more realistic measurement
    var isActive: Bool {
        get {
            return true
        }
    }
    
    // Since the screen is always active, we don't need to waste time
    func becomesActive() throws {
        return
    }
}



class IlluminatorDelayedScreen: IlluminatorSimpleScreen {
    let screenTimeout: Double
    
    var nextTimeout: Double // For setting temporarily
    
    init (containingApplication: IlluminatorApplication, label: String, screenTimeout timeoutVal: Double) {
        screenTimeout = timeoutVal
        nextTimeout = screenTimeout
        super.init(containingApplication: containingApplication, label: label)
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
    
    init (containingApplication: IlluminatorApplication,
          label: String,
          screenTimeoutSoft timeoutSoft: Double,
          screenTimeoutHard timeoutHard: Double) {
        screenTimeoutSoft = timeoutSoft
        screenTimeoutHard = timeoutHard
        nextTimeoutSoft = screenTimeoutSoft
        nextTimeoutHard = screenTimeoutHard
        super.init(containingApplication: containingApplication, label: label)
    }
    
    // To be overridden by the extender of the class
    var transientIsActive: Bool {
        get {
            return false;
        }
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
        throw IlluminatorExceptions.VerificationFailed(
            message: msg + ((hardTime.timeIntervalSinceNow > nextTimeoutHard) ? "hard" : "soft") + " timeout")
    }
}
