//
//  IlluminatorExceptions.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


public enum IlluminatorExceptions: Error {
    case warning(message: String)                   // non-fatal error; can be deferred. doesn't interrupt flow
    case incorrectScreen(message: String)           // we're on the wrong screen
    //case IndeterminateState(message: String)        // the saved state doesn't make sense
    case verificationFailed(message: String)        // we wanted something that wasn't there
    case developerError(message: String)            // the writer of the test is using Illuminator incorrectly
    case elementNotReady(message: String)           // an element failed readiness check
    case multipleElementsFound(message: String)     // multiple elements exist
    case elementNotFound(message: String)           // no element exists
}

