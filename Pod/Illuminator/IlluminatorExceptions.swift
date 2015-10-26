//
//  IlluminatorExceptions.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

enum IlluminatorExceptions: ErrorType {
    case VerificationFailed(message: String)
}

protocol WaitForible: Equatable, CustomStringConvertible {}

extension Bool: WaitForible {
    var description: String {
        get {
            return self ? "true" : "false"
        }
    }
}


// guaranteed to run at least once
func waitForResult <A: WaitForible> (seconds: Double, desired: A, what: String, getResult: () -> A) throws {
    let startTime = NSDate()
    var lastResult: A
    repeat {
        lastResult = getResult()
        if desired == lastResult {return}
    } while startTime.timeIntervalSinceNow < seconds
    throw IlluminatorExceptions.VerificationFailed(
        message: "Waiting for \(what) to become \(desired) failed after \(seconds) seconds; got \(lastResult)")
}
