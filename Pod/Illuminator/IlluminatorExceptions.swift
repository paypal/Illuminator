//
//  IlluminatorExceptions.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


public enum IlluminatorExceptions: ErrorType {
    case Warning(message: String)             // non-fatal error; can be deferred. doesn't interrupt flow
    case IncorrectScreen(message: String)     // we're on the wrong screen
    //case IndeterminateState(message: String)  // the saved state doesn't make sense
    //case VerificationFailed(message: String)  // we wanted something that wasn't there
    case DeveloperError(message: String)      // the writer of the test is using Illuminator incorrectly
}

public protocol WaitForible: Equatable, CustomStringConvertible {}

extension Bool: WaitForible {
    var description: String {
        get {
            return self ? "true" : "false"
        }
    }
}


// guaranteed to run at least once (even if seconds == 0)
// see http://stackoverflow.com/questions/31300372/uiautomation-and-xctestcase-how-to-wait-for-a-button-to-activate
// and http://stackoverflow.com/questions/31182637/delay-wait-in-a-test-case-of-xcode-ui-testing
public func waitForResult <A: WaitForible> (seconds: Double, desired: A, what: String, getResult: () -> A) throws {
    let startTime = NSDate()
    var lastResult: A
    repeat {
        lastResult = getResult()
        if desired == lastResult {return}
        print("Waiting for \(what) to become \(desired), \(startTime.timeIntervalSinceNow) of \(seconds) seconds; got \(lastResult)")
    } while (0 - startTime.timeIntervalSinceNow) < seconds
    throw IlluminatorExceptions.IncorrectScreen(
        message: "Waiting for \(what) to become \(desired) failed after \(seconds) seconds; got \(lastResult)")
}
