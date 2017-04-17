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


// guaranteed to run at least once (even if seconds == 0)
// see http://stackoverflow.com/questions/31300372/uiautomation-and-xctestcase-how-to-wait-for-a-button-to-activate
// and http://stackoverflow.com/questions/31182637/delay-wait-in-a-test-case-of-xcode-ui-testing
public func waitForResult <T: WaitForible> (_ seconds: Double, desired: T, what: String, getResult: () -> T) throws {
    let startTime = Date()
    var lastResult: T
    repeat {
        lastResult = getResult()
        if desired == lastResult {return}

        // http://stackoverflow.com/a/39743244 refresh hierarchy
        _ = XCUIApplication().navigationBars.count

    } while (0 - startTime.timeIntervalSinceNow) < seconds
    throw IlluminatorExceptions.verificationFailed(
        message: "Waiting for \(what) to become \(desired) failed after \(seconds) seconds; got \(lastResult)")
}
