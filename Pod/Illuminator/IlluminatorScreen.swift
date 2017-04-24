//
//  IlluminatorScreen.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

/**
    Illuminator screens are tied to a test case.  
    They have a name, and the concept of whether they are active (and/or become active).
 */
public protocol IlluminatorScreen: CustomStringConvertible {
    var testCaseWrapper: IlluminatorTestcaseWrapper { get }
    var label: String { get }
    var isActive: Bool { get }
    func becomesActive() throws
}

public extension IlluminatorScreen {
    /**
        CustomStringConvertible implementation
        - Returns: The screen's name (label)
     */
    var description: String {
        return label
    }

    /**
        A shortcut accessor to the screen's test case, through the wrapper
        - Returns: The screen's underlying test case
     */
    var testCase: XCTestCase {
        get {
            return testCaseWrapper.testCase
        }
    }
}


/**
     An Illuminator "screen" is an abstract concept describing a logical grouping of Illuminator actions, typically when those actions share space on the same UI view -- the screen provides a pattern for centralizing any assertions of the state of the UI.  (Specifically, asserting that the user has been presented with the correct view.)

    The base screen is the most basic concept of a screen -- one that is always available (for which the actions might invole a shake gesture, waiting a number of seconds, printing debugging information, or taking a screenshot).
 */
@available(iOS 9.0, *)
public class IlluminatorBaseScreen<T>: IlluminatorScreen {
    public let testCaseWrapper: IlluminatorTestcaseWrapper
    public let label: String
    public let app = XCUIApplication() // seems like the appropriate place to set this up

    /**
        Instantiate a screen

        - Parameters:
            - label: The screen's description, for logging purposes
            - testCaseWrapper: Illuminator's container for the underlying test case
     */
    public init (label labelVal: String, testCaseWrapper t: IlluminatorTestcaseWrapper) {
        testCaseWrapper = t
        label = labelVal
    }
    
    
    /**
         Whether the screen is currently visible to the user

         In this most basic case, we assume that the screen is always active.  This should be overridden with a more realistic measurement in subclasses
     
        - Returns: Whether the screen is currently visible to the user
     */
    public var isActive: Bool {
        return true
    }
    
    /**
        Delay until the screen becomes active, or throw.

        - Throws: nothing; this base class will never throw.
     */
    public func becomesActive() throws {
        // Since basic screens are always active, we don't need to waste time
        return
    }

    /**
        A hard-coded action for verifying that a screen is active.
 
        Note that this function is a no-op because the base screen is always active.
     
        - Returns: an empty action
     */
    public func verifyIsActive() -> IlluminatorActionGeneric<T> {
        return makeAction(label: #function) { }
    }
    
    /**
        A hard-coded action for verifying that a screen is not active.

        - Returns: an action that always fails, because base screens are always active
     */
    public func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorBaseScreen<T>(label: "null screen", testCaseWrapper: self.testCaseWrapper)
        return IlluminatorActionGeneric(label: #function, testCaseWrapper: self.testCaseWrapper, screen: nullScreen, file: #file, line: #line) { state in
            throw IlluminatorError.IncorrectScreen(message: "IlluminatorBaseScreen instances are always active")
        }
    }
    
    /**
        Create an action tied to this screen that executes a supplied task, which either reads or writes the test state.
    
        This function is essentially syntactic sugar for Illuminator.

        - Parameters:
            - label: The action's name -- by default, taken as the name of the function that calls `makeAction`
            - task: The action's actual action
        - Returns: an action that, when applied, executes the supplied closure
     */
    public func makeAction(label l: String = #function, file: StaticString = #file, line: UInt = #line, task: (T) throws -> T) -> IlluminatorActionGeneric<T> {
        return IlluminatorActionGeneric(label: l, testCaseWrapper: self.testCaseWrapper, screen: self, file: file, line: line, task: task)
    }
    
    /**
     Create an action tied to this screen that executes a supplied task, which neither reads nor writes the test state.

        This function is essentially syntactic sugar for Illuminator.

        - Parameters:
            - label: The action's name -- by default, taken as the name of the function that calls `makeAction`
            - task: The action's actual action
        - Returns: an action that, when applied, executes the supplied closure
     */
    public func makeAction(label l: String = #function, file: StaticString = #file, line: UInt = #line, task: () throws -> ()) -> IlluminatorActionGeneric<T> {
        return makeAction(label: l, file: file, line: line) { (state: T) in
            try task()
            return state
        }
    }
    
    /**
        Create an action tied to this screen by composing two other actions

        This function is essentially syntactic sugar for Illuminator.

        - Parameters:
            - firstAction: The first action to be executed
            - secondAction: The second action to be executed
            - label: The action's name -- by default, taken as the name of the function that calls `makeAction`
        - Returns: an action that, when applied, executes the supplied closure
     */
    public func makeAction(firstAction: IlluminatorActionGeneric<T>, secondAction: IlluminatorActionGeneric<T>, label l: String = #function, file: StaticString = #file, line: UInt = #line) -> IlluminatorActionGeneric<T> {
        return makeAction(label: l, file: file, line: line) { (state: T) in
            return try secondAction.task(try firstAction.task(state))
        }
    }
    
    /**
        Create an action tied to this screen by composing an array of actions

        This function is essentially syntactic sugar for Illuminator.

        - Parameters:
            - actions: An array of actions to be executed, in order
            - label: The action's name -- by default, taken as the name of the function that calls `makeAction`
        - Returns: an action that, when applied, executes the supplied closure
     */
    public func makeAction(actions: [IlluminatorActionGeneric<T>], label l: String = #function, file: StaticString = #file, line: UInt = #line) -> IlluminatorActionGeneric<T> {
        // need 2 actions to do anything useful
        guard actions.count > 0 else {
            return makeAction() {
                throw IlluminatorError.DeveloperError(message: "Trying to make a composite Illuminator action from none")
            }
        }
        guard actions.count > 1 else { return actions[0] }
  
        return actions.tail.reduce(actions[0]) { makeAction($0, secondAction: $1, file: file, line: line) }
    }
}

/**
    The delayed screen is the most common type of screen -- one that becomes available after a short delay (due to a network fetch, animation, or background processing.
 
    The timeout can be overridden on a case-by-case basis, after which the default timeout will resume.
 */
@available(iOS 9.0, *)
public class IlluminatorDelayedScreen<T>: IlluminatorBaseScreen<T> {
    let screenTimeout: Double
    var nextTimeout: Double // For setting temporarily
    
    /**
        Instantiate a delayed screen

        - Parameters:
            - label: The screen's description, for logging purposes
            - testCaseWrapper: Illuminator's container for the underlying test case
            - screenTimeout: The amount of time that the test should wait for the screen to become active before failing
     */
    public init (label labelVal: String, testCaseWrapper t: IlluminatorTestcaseWrapper, screenTimeout s: Double) {
        screenTimeout = s
        nextTimeout = s
        super.init(label: labelVal, testCaseWrapper: t)
    }
    
    
    /**
        Wait for the screen to become active; return if it does, throw if it times out.
        - Throws: `IlluminatorError.IncorrectScreen` if the screen does not become active
     */
    override public func becomesActive() throws {
        defer { nextTimeout = screenTimeout }  // reset the timeout after we run
        do {
            try waitForResult(nextTimeout, desired: true, what: "[\(self) isActive]", getResult: { self.isActive })
        } catch IlluminatorError.VerificationFailed(let message) {
            // convert error type, for accuracy
            throw IlluminatorError.IncorrectScreen(message: message)
        }
    }
    
    /**
        A hard-coded action for verifying that a screen is active.

        - Returns: an action
     */
    override public func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorBaseScreen<T>(label: "null screen", testCaseWrapper: self.testCaseWrapper)
        return IlluminatorActionGeneric(label: #function, testCaseWrapper: self.testCaseWrapper, screen: nullScreen, file: #file, line: #line) { state in
            var stillActive: Bool
            do {
                try waitForResult(self.nextTimeout, desired: false, what: "[\(self) isActive]", getResult: { self.isActive })
                stillActive = false
            } catch IlluminatorError.VerificationFailed {
                stillActive = true
            }
            
            if stillActive {
                throw IlluminatorError.IncorrectScreen(message: "\(self) failed to become inactive")
            }
            return state
        }
    }
}

/**
    The delayed screen with transient represents screens that becomes available after a delay, as well as the disappearance of a transient dialog (like a spinner or progress bar).  This is implemented as a "hard timeout" -- an overall limit on the time, and a "soft limit" -- the maximum amount of time that it should take the screen to become active after the transient is no longer active.


 */
@available(iOS 9.0, *)
public class IlluminatorScreenWithTransient<T>: IlluminatorBaseScreen<T> {
    let screenTimeoutSoft: Double   // how long we'd wait if we didn't see the transient
    let screenTimeoutHard: Double   // how long we'd wait if we DID see the transient
    
    var nextTimeoutSoft: Double     // Sometimes we may want to adjust the timeouts temporarily
    var nextTimeoutHard: Double
    
    
    /**
        Instantiate a delayed screen

        - Parameters:
            - label: The screen's description, for logging purposes
            - testCaseWrapper: Illuminator's container for the underlying test case
            - screenTimeoutSoft: The amount of time that the test should wait for the screen to become active after the transient is no longer active
            - screenTimeoutHard: The amount of time that the test should wait for the screen to become active before failing, irrespective of the transient
     */
    public init (label labelVal: String, testCaseWrapper t: IlluminatorTestcaseWrapper,                                       screenTimeoutSoft timeoutSoft: Double, screenTimeoutHard timeoutHard: Double) {
        screenTimeoutSoft = timeoutSoft
        screenTimeoutHard = timeoutHard
        nextTimeoutSoft = screenTimeoutSoft
        nextTimeoutHard = screenTimeoutHard
        super.init(label: labelVal, testCaseWrapper: t)
    }
    
    /**
        Whether the transient is currently active
 
        This must be overridden by the extender of the class.
 
        - Returns: Whether the transient is active
     */
    public var transientIsActive: Bool {
        return false;
    }
    
    /**
        Wait for the screen to become active; return if it does, throw if it times out.
        - Throws: `IlluminatorError.IncorrectScreen` if the screen does not become active
     */
    override public func becomesActive() throws {
        defer {
            nextTimeoutSoft = screenTimeoutSoft
            nextTimeoutHard = screenTimeoutHard
        }

        do {
            // full time if transientIsActive
            // early fail if !transientIsActive and failed to wait for isActive
            try waitForResult(nextTimeoutHard, desired: false, what: "[\(self) transientIsActive]") {

                do {
                    try waitForResult(self.nextTimeoutHard, desired: false, what: "[\(self) transientIsActive]") {
                        self.transientIsActive
                    }
                    try waitForResult(self.nextTimeoutSoft, desired: true, what: "[\(self) isActive]") {
                        self.isActive
                    }
                } catch IlluminatorError.VerificationFailed {
                    // dont worry about it; if transient is active, we go around again
                    // if transient is not active,
                } catch {
                    print("Please report this IlluminatorScreenWithTransient becomesActive error! \(error)")
                }
                
                return self.transientIsActive
            }
        } catch IlluminatorError.VerificationFailed {
            throw IlluminatorError.IncorrectScreen(message: "\(self) failed to become active (and transient inactive) before hard timeout \(nextTimeoutHard)")
        }


        if !isActive {
            throw IlluminatorError.IncorrectScreen(message: "\(self) failed to become active (after transient inactive) before soft timeout \(nextTimeoutSoft)")
        }
    }
    
    /**
        A hard-coded action for verifying that a screen is not active.

        This function is almost certainly broken.  It needs a test case, and to be converted to the style of verifyIsActive

         - Returns: an action that fails if the screen does not become inactive
     */
   override public func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorBaseScreen<T>(label: "null screen", testCaseWrapper: self.testCaseWrapper)
    return IlluminatorActionGeneric(label: #function, testCaseWrapper: self.testCaseWrapper, screen: nullScreen, file: #file, line: #line) { state in
            
            let hardTime = NSDate()
            var softTime = NSDate()
            repeat {
                if self.transientIsActive {
                    softTime = NSDate()
                } else if !self.isActive {
                    return state
                }
            } while (0 - hardTime.timeIntervalSinceNow) < self.nextTimeoutHard && (0 - softTime.timeIntervalSinceNow) < self.nextTimeoutSoft
            
            if self.isActive {
                throw IlluminatorError.IncorrectScreen(message: "\(self) failed to become inactive")
            }
            return state
        }
    }
}

