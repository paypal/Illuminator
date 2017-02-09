//
//  IlluminatorError.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


/**
    In order to provide relevant file/line information, all Illuminator errors should be thrown via `IllumiantorException.fail()`.  A prerequisite for this is having all Illuminator exceptions use the same associated type signature.

    Based on a trick found here:
    https://appventure.me/2016/04/23/associated-types-enum-raw-value-initializers/

 */
public enum IlluminatorError: ErrorType, CustomStringConvertible {

    // non-fatal error; can be deferred. doesn't interrupt flow
    case Warning(message: String)

    // we're on the wrong screen
    case IncorrectScreen(message: String)

    // we wanted something that wasn't there
    case VerificationFailed(message: String)

    // the writer of the test is using Illuminator incorrectly
    case DeveloperError(message: String)

    // an element failed readiness check
    case ElementNotReady(message: String)

    // multiple elements exist
    case MultipleElementsFound(message: String)

    // no element exists
    case ElementNotFound(message: String)

    /**
        A human-readable description of the error

        - Returns: The error's identifier, and its associated message
    */
    public var description: String {
        switch (self) {
        case .Warning(let message):               return "IlluminatorError.Warning: \(message)"
        case .IncorrectScreen(let message):       return "IlluminatorError.IncorrectScreen: \(message)"
        case .VerificationFailed(let message):    return "IlluminatorError.VerificationFailed: \(message)"
        case .DeveloperError(let message):        return "IlluminatorError.DeveloperError: \(message)"
        case .ElementNotReady(let message):       return "IlluminatorError.ElementNotReady: \(message)"
        case .MultipleElementsFound(let message): return "IlluminatorError.MultipleElementsFound: \(message)"
        case .ElementNotFound(let message):       return "IlluminatorError.ElementNotFound: \(message)"
        }
    }
}
