//
//  IlluminatorTestCaseWrapper.swift
//  Pods
//
//  Created by Ian Katz on 11/29/16.
//
//

import XCTest

/**
    This class may be unnecessary, but it provides a way to separate Illuminator's concerns regarding the XCTestCase class from any site-specific extensions to this class

    There was also a possibly misguided attempt to wrap continueAfterFailure in a push/pop-able operation, see 
    http://stackoverflow.com/questions/20998788/failing-a-xctestcase-with-assert-without-the-test-continuing-to-run-but-without

*/
public class IlluminatorTestcaseWrapper {
    let testCase: XCTestCase
    var continueAfterFailures = [Bool]()

    public init(testCase t: XCTestCase) {
        testCase = t
        initContinueAfterFailure()
    }

    func initContinueAfterFailure() {
        continueAfterFailures = [testCase.continueAfterFailure]
        sanityCheck()
    }

    public func pushContinueAfterFailure(val: Bool) {
        sanityCheck()
        continueAfterFailures.append(val)
        testCase.continueAfterFailure = val
    }

    public func popContinueAfterFailure() {
        sanityCheck()
        continueAfterFailures.removeLast()
        testCase.continueAfterFailure = continueAfterFailures.last!
    }

    func sanityCheck() {
        if testCase.continueAfterFailure != continueAfterFailures.last! {
            //TODO: some kind of warning
        }
    }

}
