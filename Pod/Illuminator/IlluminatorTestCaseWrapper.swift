//
//  IlluminatorTestCaseWrapper.swift
//  Pods
//
//  Created by Ian Katz on 11/29/16.
//
//

import XCTest

// this may not work
// see http://stackoverflow.com/questions/20998788/failing-a-xctestcase-with-assert-without-the-test-continuing-to-run-but-without

// Actions need the ability to push/pop the continueAfterFailure variable.
// We don't care whose framework "owns" the base class, we just need to wrap it.
open class IlluminatorTestcaseWrapper {
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

    open func pushContinueAfterFailure(_ val: Bool) {
        sanityCheck()
        continueAfterFailures.append(val)
        testCase.continueAfterFailure = val
    }

    open func popContinueAfterFailure() {
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
