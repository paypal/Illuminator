//
//  IlluminatorTestProgress.swift
//  Pods
//
//  Created by Katz, Ian on 3/16/16.
//
//

import Foundation
import XCTest

/**
    This protocol allows custom handling of results.  For example, screenshots of failure states or desktop notifications
 */
public protocol IlluminatorTestResultHandler {
    associatedtype AbstractStateType: CustomStringConvertible
    func handleTestResult(_ progress: IlluminatorTestProgress<AbstractStateType>) -> ()
}


/**
    This struct is a cheap hack to get a generic protocol

    https://milen.me/writings/swift-generic-protocols/
 */
struct IlluminatorTestResultHandlerThunk<T: CustomStringConvertible> : IlluminatorTestResultHandler {
    typealias AbstractStateType = T
    
    // closure which will be used to implement `handleTestResult()` as declared in the protocol
    fileprivate let _handleTestResult : (IlluminatorTestProgress<T>) -> ()
    
    // `T` is effectively a handle for `AbstractStateType` in the protocol
    init<P : IlluminatorTestResultHandler>(_ dep : P) where P.AbstractStateType == T {
        // requires Swift 2, otherwise create explicit closure
        _handleTestResult = dep.handleTestResult
    }
    
    func handleTestResult(_ progress: IlluminatorTestProgress<AbstractStateType>) -> () {
        // any protocol methods are implemented by forwarding
        return _handleTestResult(progress)
    }
}

/**
    This struct captures file and line information to give good feedback when run from the IDE
 */
public struct IlluminatorErrorInfo: CustomStringConvertible {
    var message: String
    var file: StaticString
    var line: UInt

    public var description: String {
        let basename = ("\(file)" as NSString).lastPathComponent
        return "\(message) (\(basename):\(line))"
    }
}


/**
    IllumintorTestProgress is a composite state.  It contains the app test state (any stateful data that must be shared between test steps), and the state of the test itself (passing, failing, or flagging).
 
    This enum uses a functional technique to apply an IlluminatorAction to an given state, returning a new state.  These applciations are designed to chain together.

 */
@available(iOS 9.0, *)
public enum IlluminatorTestProgress<T: CustomStringConvertible>: CustomStringConvertible {
    case passing(T)
    case flagging(T, [IlluminatorErrorInfo])
    case failing(T, [IlluminatorErrorInfo])

    /**
        A description of an action, with the screen if that exists

        - Parameters:
            - action: the action to render
        - Returns: The description
     */
    func actionDescription(_ action: IlluminatorActionGeneric<T>) -> String {
        guard let screen = action.screen else {
            return "<screenless> \(action.description)"
        }
        return "\(screen.description).\(action.description)"
    }

    /**
        Apply an action to a state of progress, returning a new state of progress
        
        - Parameters:
            - action: The action to apply
            - checkScreen: whether to assert that the action's screen is active
            - file: The file in which the action was applied
            - line: The line on which the action was applied
        - Returns: A new test progress state, according to the result of the action
     */
    func applyAction(_ action: IlluminatorActionGeneric<T>, checkScreen: Bool, file: StaticString, line: UInt) -> IlluminatorTestProgress<T> {
        var myState: T!
        var myErrors: [IlluminatorErrorInfo]!
        
        // fall-through fail, or pick up state and strings
        switch self {
        case .failing:
            return self
        case .flagging(let state, let errInfos):
            myState = state
            myErrors = errInfos
        case .passing(let state):
            myState = state
            myErrors = []
        }
        
        print("Applying \(actionDescription(action))")

        // check the screen first, because if it fails here then it's a total failure
        if checkScreen {
            if let s = action.screen {
                do {
                    try s.becomesActive()
                } catch IlluminatorError.incorrectScreen(let message) {
                    // for incorrect screen, show the IDE error at the action application
                    let errInfo = IlluminatorErrorInfo(message: "Incorrect screen for \(actionDescription(action)): \(message)", file: file, line: line)
                    myErrors.append(errInfo)
                    return .failing(myState, myErrors)
                } catch let unknownError {
                    // for all other errors, show the IDE error at the action implementation
                    let errInfo = IlluminatorErrorInfo(message: "Error applying \(actionDescription(action)): \(unknownError)", file: action.file, line: action.line)
                    myErrors.append(errInfo)
                    return .failing(myState, myErrors)
                }
            }
        }
        
        // tiny function to decorate action errors
        let decorate = {(label: String, errMessage: String) -> IlluminatorErrorInfo in
            let newMessage = "\(action.description) \(label): \(errMessage)"
            return IlluminatorErrorInfo(message: newMessage, file: action.file, line: action.line)
        }
        
        // passing, flagging, or failing as appropriate
        do {
            let newState = try action.task(myState)
            if myErrors.isEmpty {
                return .passing(newState)
            } else {
                return .flagging(newState, myErrors)
            }
        } catch IlluminatorError.warning(let message) {
            myErrors.append(decorate("Warning", message))
            return .flagging(myState, myErrors)
        } catch let unknownError {
            myErrors.append(decorate("Error", "\(unknownError)"))
            return .failing(myState, myErrors)
        }
    }
    
    /**
        Apply an action after asserting that its screen is active

        Note that a failure to apply an action may not result in a test failure unless the `.finish()` function is called.

        - Parameters:
            - action: The action to apply
            - file: The file in which the action was applied
            - line: The line on which the action was applied
        - Returns: The progress state as a result of the action
     */
    public func apply(_ action: IlluminatorActionGeneric<T>, file: StaticString = #file, line: UInt = #line) -> IlluminatorTestProgress<T> {
        return applyAction(action, checkScreen: true, file: file, line: line)
    }
    
    /**
        Apply an action without asserting that its screen is active

        Note that a failure to apply an action may not result in a test failure unless the `.finish()` function is called.

        - Parameters:
            - action: The action to apply
            - file: The file in which the action was applied
            - line: The line on which the action was applied
        - Returns: The progress state as a result of the action
     */
    public func blindly(_ action: IlluminatorActionGeneric<T>, file: StaticString = #file, line: UInt = #line) -> IlluminatorTestProgress<T> {
        return applyAction(action, checkScreen: false, file: file, line: line)
    }
    
    /**
        Handle the final test result using a protocol-conformant object, then pass or fail as appropriate

        - Parameters:
            - handler: The protocol-conformant object that will handle the test result
     */
    public func finish<P: IlluminatorTestResultHandler>(_ handler: P) where P.AbstractStateType == T {
        let genericHandler: IlluminatorTestResultHandlerThunk<T> = IlluminatorTestResultHandlerThunk(handler)
        genericHandler.handleTestResult(self)
        
        // worst case, we handle it ourselves with a default implementation
        finish()
    }

    /**
        Handle the final test result using a closure, then pass or fail as appropriate

        - Parameters:
            - handler: The closure that will handle the test result
     */
    public func finish(_ handler: (IlluminatorTestProgress<T>) -> ()) {
        handler(self)
        finish()
    }
    
    /**
        Interpret the final result in XCTest terms -- triggering a test failure if appropriate
     */
    public func finish() {
        // We have overloaded XCTAssert specifically to be able to do this
        XCTAssert(self)
    }

    /**
        CustomStringConvertible implementation
        - Returns: A summary of the composite (test & app) state
     */
    public var description: String {
        get {
            switch self {
            case .failing(let state, let messages):
                return "Failing: \(messages); App state: \(state)"
            case .flagging(let state, let messages):
                return "Flagging: \(messages); App state: \(state)"
            case .passing(let state):
                return "Passing; App state: \(state)"
            }
        }
    }

}

/**
    Interpret Illuminator test progress as either passing or failing

    - Parameters:
        - progress: The state of an Illuminator test
 */
public func XCTAssert<T>(_ progress: IlluminatorTestProgress<T>) {
    switch progress {
    case .failing(_, let errInfos):
        let info = errInfos[0]
        XCTFail("Illuminator Failure: \(errInfos.map({$0.message}).joined(separator: "; "))", file: info.file, line: info.line)
    case .flagging(_, let errInfos):
        let info = errInfos[0]
        XCTFail("Illuminator Deferred Failure: \(errInfos.map({$0.message}).joined(separator: "; "))", file: info.file, line: info.line)
    case .passing:
        return
    }
}

