//
//  IlluminatorTestCaseWrapper.swift
//  Pods
//
//  Created by Ian Katz on 11/29/16.
//
//

import XCTest

// Actions need the ability to push/pop the continueAfterFailure variable.
// We don't care whose framework "owns" the base class, we just need to wrap it.
public class IlluminatorTestcaseWrapper {
    let testCase: XCTestCase
    var continueAfterFailures = [Bool]()

    init(testCase t: XCTestCase) {
        testCase = t
        initContinueAfterFailure()
    }

    func initContinueAfterFailure() {
        continueAfterFailures = [testCase.continueAfterFailure]
        sanityCheck()
    }

    func pushContinueAfterFailure(val: Bool) {
        sanityCheck()
        continueAfterFailures.append(val)
        testCase.continueAfterFailure = val
    }

    func popContinueAfterFailure() {
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
