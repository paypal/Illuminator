//
//  IlluminatorTestProgress.swift
//  Pods
//
//  Created by Katz, Ian on 3/16/16.
//
//

import Foundation
import XCTest

/*
 * This protocol allows custom handling of results.  For example, screenshots of failure states or desktop notifications
 * isPass and isFail can both be false -- it indicates a "Flagging" state.  They are guaranteed to not both be true
 */
public protocol IlluminatorTestResultHandler {
    typealias AbstractStateType
    func handleTestResult(isPass: Bool, isFail: Bool, state: AbstractStateType?, errorMessages: [String]) -> ()
}


// cheap hack to get a generic protocol
// https://milen.me/writings/swift-generic-protocols/
struct IlluminatorTestResultHandlerThunk<T> : IlluminatorTestResultHandler {
    typealias AbstractStateType = T
    
    // closure which will be used to implement `handleTestResult()` as declared in the protocol
    private let _handleTestResult : (isPass: Bool, isFail: Bool, state: T?, errorMessages: [String]) -> ()
    
    // `T` is effectively a handle for `AbstractStateType` in the protocol
    init<P : IlluminatorTestResultHandler where P.AbstractStateType == T>(_ dep : P) {
        // requires Swift 2, otherwise create explicit closure
        _handleTestResult = dep.handleTestResult
    }
    
    func handleTestResult(isPass: Bool, isFail: Bool, state: AbstractStateType?, errorMessages: [String]) -> () {
        // any protocol methods are implemented by forwarding
        return _handleTestResult(isPass: isPass, isFail: isFail, state: state, errorMessages: errorMessages)
    }
}


/*
 * This enum uses some functional magic to apply a set of device actions to an initial (passing) state.
 * Each action acts on the current state of the XCUIApplication() and a state variable that may optionally be passed to it
 * Thus, each action is by itself stateless.
 */
@available(iOS 9.0, *)
public enum IlluminatorTestProgress<T> {
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
    func applyAction(action: IlluminatorActionGeneric<T>, checkScreen: Bool) -> IlluminatorTestProgress<T> {
        
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
                } catch let unknownError {
                    myErrStrings.append("Caught error: \(unknownError)")
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
        } catch let unknownError {
            myErrStrings.append("Caught error: \(unknownError)")
            return .Failing(myErrStrings)
        }
    }
    
    // apply an action, checking the screen first
    public func apply(action: IlluminatorActionGeneric<T>) -> IlluminatorTestProgress<T> {
        return applyAction(action, checkScreen: true)
    }
    
    // apply an action, without checking the screen first
    public func blindly(action: IlluminatorActionGeneric<T>) -> IlluminatorTestProgress<T> {
        return applyAction(action, checkScreen: false)
    }
    
    // handle the final result in terms of a test case
    public func finish<P: IlluminatorTestResultHandler where P.AbstractStateType == T>(handler: P) {
        let (isPassing, isFailing, state, errorMessages) = normalize()
        
        let genericHandler: IlluminatorTestResultHandlerThunk<T> = IlluminatorTestResultHandlerThunk(handler)
        genericHandler.handleTestResult(isPassing, isFail: isFailing, state: state, errorMessages: errorMessages)
        
        // worst case, we handle it ourselves with a default implementation
        finish()
    }
    
    // interpret the final result in terms of a test case
    public func finish() {
        let (isPassing, _, _, errorMessages) = normalize()
        XCTAssert(isPassing, errorMessages.joinWithSeparator("; "))
    }
    
}
