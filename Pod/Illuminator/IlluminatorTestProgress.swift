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
    associatedtype AbstractStateType: CustomStringConvertible
    func handleTestResult(progress: IlluminatorTestProgress<AbstractStateType>) -> ()
}


// cheap hack to get a generic protocol
// https://milen.me/writings/swift-generic-protocols/
struct IlluminatorTestResultHandlerThunk<T: CustomStringConvertible> : IlluminatorTestResultHandler {
    typealias AbstractStateType = T
    
    // closure which will be used to implement `handleTestResult()` as declared in the protocol
    private let _handleTestResult : (IlluminatorTestProgress<T>) -> ()
    
    // `T` is effectively a handle for `AbstractStateType` in the protocol
    init<P : IlluminatorTestResultHandler where P.AbstractStateType == T>(_ dep : P) {
        // requires Swift 2, otherwise create explicit closure
        _handleTestResult = dep.handleTestResult
    }
    
    func handleTestResult(progress: IlluminatorTestProgress<AbstractStateType>) -> () {
        // any protocol methods are implemented by forwarding
        return _handleTestResult(progress)
    }
}


/*
 * This enum uses some functional magic to apply a set of device actions to an initial (passing) state.
 * Each action acts on the current state of the XCUIApplication() and a state variable that may optionally be passed to it
 * Thus, each action is by itself stateless.
 */
@available(iOS 9.0, *)
public enum IlluminatorTestProgress<T: CustomStringConvertible> {
    case Passing(T)
    case Flagging(T, [String])
    case Failing(T, [String])
    
    // apply an action to a state of progress, returning a new state of progress
    func applyAction(action: IlluminatorActionGeneric<T>, checkScreen: Bool) -> IlluminatorTestProgress<T> {
        var myState: T!
        var myErrStrings: [String]!
        
        // fall-through fail, or pick up state and strings
        switch self {
        case .Failing:
            return self
        case .Flagging(let state, let errStrings):
            myState = state
            myErrStrings = errStrings
        case .Passing(let state):
            myState = state
            myErrStrings = []
        }
        
        
        // check the screen first, because if it fails here then it's a total failure
        if checkScreen {
            if let s = action.screen {
                do {
                    try s.becomesActive()
                } catch IlluminatorExceptions.IncorrectScreen(let message) {
                    myErrStrings.append(message)
                    return .Failing(myState, myErrStrings)
                } catch let unknownError {
                    myErrStrings.append("Caught error: \(unknownError)")
                    return .Failing(myState, myErrStrings)
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
            return .Failing(myState, myErrStrings)
            //} catch IlluminatorExceptions.IndeterminateState(let message) {
            //    myErrStrings.append(decorate("indeterminate state", message))
            //    return .Failing(myErrStrings)
            //} catch IlluminatorExceptions.VerificationFailed(let message) {
            //    myErrStrings.append(decorate("verification failed", message))
            //    return .Failing(myErrStrings)
        } catch let unknownError {
            myErrStrings.append("Caught error: \(unknownError)")
            return .Failing(myState, myErrStrings)
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
        let genericHandler: IlluminatorTestResultHandlerThunk<T> = IlluminatorTestResultHandlerThunk(handler)
        genericHandler.handleTestResult(self)
        
        // worst case, we handle it ourselves with a default implementation
        finish()
    }
    
    // interpret the final result in terms of a test case
    public func finish() {
        XCTAssert(self)
    }
    
}

// How to assert Illuminator test progress is pass
public func XCTAssert<T>(progress: IlluminatorTestProgress<T>, file f: StaticString = #file, line l: UInt = #line) {
    switch progress {
    case .Failing(_, let errStrings):
        XCTFail("Illuminator Failure: \(errStrings.joinWithSeparator("; "))", file: f, line: l)
    case .Flagging(_, let errStrings):
        XCTFail("Illuminator Deferred Failure: \(errStrings.joinWithSeparator("; "))", file: f, line: l)
    case .Passing:
        return
    }
}

