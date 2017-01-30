//
//  IlluminatorExceptions.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

public struct IlluminatorErrorInfo {
    var message: String
    var file: StaticString
    var line: UInt
}

/**
    In order to provide relevant file/line information, all Illuminator errors should be thrown via `IllumiantorException.fail()`.  A prerequisite for this is having all Illuminator exceptions use the same associated type signature.

    Based on a trick found here:
    https://appventure.me/2016/04/23/associated-types-enum-raw-value-initializers/

 */
public enum IlluminatorError: ErrorType {

    // non-fatal error; can be deferred. doesn't interrupt flow
    case Warning(info: IlluminatorErrorInfo)

    // we're on the wrong screen
    case IncorrectScreen(info: IlluminatorErrorInfo)

    // we wanted something that wasn't there
    case VerificationFailed(info: IlluminatorErrorInfo)

    // the writer of the test is using Illuminator incorrectly
    case DeveloperError(info: IlluminatorErrorInfo)

    // an element failed readiness check
    case ElementNotReady(info: IlluminatorErrorInfo)

    // multiple elements exist
    case MultipleElementsFound(info: IlluminatorErrorInfo)

    // no element exists
    case ElementNotFound(info: IlluminatorErrorInfo)

}

/**
    Shorthand for throwing an exception that includes file/line information
    
    Based on a trick found here, in which it is revealed that swift enum cases that have associated types are actually closures:
    https://appventure.me/2016/04/23/associated-types-enum-raw-value-initializers/

    - Parameters:
        - exception: An IlluminatorException case, without associated type
        - message: The string to pass to the error
        - file: The file in which the error was thrown
        - line: The line on which the error was thrown

 */
public func illuminate(errorConstructor: (IlluminatorErrorInfo) -> IlluminatorError, message: String, file: StaticString = #file, line: UInt = #line) throws {
    let info = IlluminatorErrorInfo(message: message, file: file, line: line)
    throw errorConstructor(info)
}
