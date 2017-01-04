//
//  IlluminatorExceptions.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


public enum IlluminatorExceptions: ErrorType {
    case Warning(message: String)                   // non-fatal error; can be deferred. doesn't interrupt flow
    case IncorrectScreen(message: String)           // we're on the wrong screen
    //case IndeterminateState(message: String)        // the saved state doesn't make sense
    case VerificationFailed(message: String)        // we wanted something that wasn't there
    case DeveloperError(message: String)            // the writer of the test is using Illuminator incorrectly
    case ElementNotReady(message: String)           // an element failed readiness check
    case MultipleElementsFound(message: String)     // multiple elements exist
    case ElementNotFound(message: String)           // no element exists
}

public protocol WaitForible: Equatable, CustomStringConvertible {}

extension Bool: WaitForible {
    var description: String {
        get {
            return self ? "true" : "false"
        }
    }
}

// fix a VERY cryptic error
// https://bugs.swift.org/browse/SR-2936
extension String: WaitForible {
    public var description: String {
        get {
            return self
        }
    }
}


// guaranteed to run at least once (even if seconds == 0)
// see http://stackoverflow.com/questions/31300372/uiautomation-and-xctestcase-how-to-wait-for-a-button-to-activate
// and http://stackoverflow.com/questions/31182637/delay-wait-in-a-test-case-of-xcode-ui-testing
public func waitForResult <T: WaitForible> (seconds: Double, desired: T, what: String, getResult: () -> T) throws {
    let startTime = NSDate()
    var lastResult: T
    repeat {
        lastResult = getResult()
        if desired == lastResult {return}
        
        // http://stackoverflow.com/a/39743244 refresh hierarchy
        _ = XCUIApplication().navigationBars.count

    } while (0 - startTime.timeIntervalSinceNow) < seconds
    throw IlluminatorExceptions.VerificationFailed(
        message: "Waiting for \(what) to become \(desired) failed after \(seconds) seconds; got \(lastResult)")
}
