//
//  WaitForResult.swift
//  Illuminator
//
//  Created by Ian Katz on 2017-01-05.
//

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


/**
    Assert that a closure returns a desired result within a time limit
 
    Guaranteed to run at least once (even if seconds == 0)
 
    See also
    - http://stackoverflow.com/questions/31300372/uiautomation-and-xctestcase-how-to-wait-for-a-button-to-activate
    - http://stackoverflow.com/questions/31182637/delay-wait-in-a-test-case-of-xcode-ui-testing

    - Parameters:
        - seconds: The amount of time to wait before failing
        - desired: The value needed for successful exit
        - what: A description of what is being waited for, for logging
        - getResult: A function that returns the value that will be compared with the desired value
    - Throws: `IlluminatorError.VerificationFailed` if the desired and actual values do not become equal before the time limit has passed
 */
public func waitForResult <T: WaitForible> (seconds: Double, desired: T, what: String, getResult: () -> T) throws {
    let startTime = NSDate()
    var lastResult: T
    repeat {
        lastResult = getResult()
        if desired == lastResult {return}

        // http://stackoverflow.com/a/39743244 refresh hierarchy
        _ = XCUIApplication().navigationBars.count

    } while (0 - startTime.timeIntervalSinceNow) < seconds
        throw IlluminatorError.VerificationFailed(message: "Waiting for \(what) to become \(desired) failed after \(seconds) seconds; got \(lastResult)")
}
