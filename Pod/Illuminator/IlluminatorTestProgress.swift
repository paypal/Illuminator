//
//  IlluminatorTestProgress.swift
//  Pods
//
//  Created by Katz, Ian on 3/16/16.
//
//

import Foundation
import KIF

enum IlluminatorTestProgress<T> {
    case Passing(T)
    case Flagging(T, [String])
    case Failing([String])
    
    // single purpose parsing of enum's state
    func normalize() -> (isPass: Bool, isFail: Bool, state: T?, errorMessages: [String]) {
        switch self {
        case Failing(let errStrings):
            return (false, true, nil, errStrings)
        case Flagging(let state, let errStrings):
            return (false, false, state, errStrings)
        case Passing(let state):
            return (true, false, state, [])
        }
    }
    
    // apply an action to a state of progress, returning a new state of progress
    func applyAction(action: IlluminatorActionGeneric<T>, checkScreen: Bool) throws -> IlluminatorTestProgress<T> {
        
        let info = normalize()
        
        if info.isFail {
            return .Failing(info.errorMessages)
        }
        
        let myState = info.state!
        var myErrStrings = info.errorMessages
        
        // check the screen first, because if it fails here then it's a total failure
        if checkScreen {
            if let s = action.screen {
                do {
                    try s.becomesActive()
                } catch IlluminatorExceptions.IncorrectScreen(let message) {
                    myErrStrings.append(message)
                    return .Failing(myErrStrings)
                }
            }
        }
        
        // tiny function to decorate action errors
        let decorate = {(label: String, message: String) -> String in
            return "\(action.description) \(label): \(message)"
        }
        
        // passing, flagging, or failing as appropriate
        do {
            let newState = try action.task(myState)
            if myErrStrings.isEmpty {
                return .Passing(newState)
            } else {
                return .Flagging(newState, myErrStrings)
            }
        } catch IlluminatorExceptions.Warning(let message) {
            myErrStrings.append(decorate("warning", message))
            return .Flagging(myState, myErrStrings)
        } catch IlluminatorExceptions.IncorrectScreen(let message) {
            myErrStrings.append(decorate("failed screen check", message))
            return .Failing(myErrStrings)
            //} catch IlluminatorExceptions.IndeterminateState(let message) {
            //    myErrStrings.append(decorate("indeterminate state", message))
            //    return .Failing(myErrStrings)
            //} catch IlluminatorExceptions.VerificationFailed(let message) {
            //    myErrStrings.append(decorate("verification failed", message))
            //    return .Failing(myErrStrings)
        }
    }
    
    // apply an action, checking the screen first
    func apply(action: IlluminatorActionGeneric<T>) throws -> IlluminatorTestProgress<T> {
        return try applyAction(action, checkScreen: true)
    }
    
    // apply an action, without checking the screen first
    func check(action: IlluminatorActionGeneric<T>) throws -> IlluminatorTestProgress<T> {
        return try applyAction(action, checkScreen: false)
    }
    
    // interpret the final result in terms of a test case
    func finish(testCase: KIFTestCase) {
        let (isPassing, _, _, errorMessages) = normalize()
        XCTAssert(isPassing, errorMessages.joinWithSeparator("; "))
    }
    
}



