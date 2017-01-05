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

