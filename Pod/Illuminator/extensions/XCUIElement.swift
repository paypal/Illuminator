//
//  XCUIElement.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)

/**
    A string-representable optionset for testing element readiness
    
    pattern via http://www.swift-studies.com/blog/2015/6/17/exploring-swift-20-optionsettypes
 */
public struct IlluminatorElementReadiness: OptionSet, CustomStringConvertible {
    fileprivate enum Readiness: Int, CustomStringConvertible {
        case exists       = 1
        case inMainWindow = 2
        case hittable     = 4

        /**
             Implementation for CustomStringConvertible

             - Returns: A string describing the option
         */
        var description : String {
            var shift = 0
            while (rawValue >> shift != 1) { shift = shift + 1 } // TODO: probably a better way to do this
            return ["Exists", "Down", "Hittable"][shift]
        }
    }

    public  let rawValue: Int
    public  init(rawValue: Int) { self.rawValue = rawValue}
    fileprivate init(_ readiness: Readiness) { self.rawValue = readiness.rawValue }

    static let Exists        = IlluminatorElementReadiness(Readiness.exists)
    static let InMainWindow  = IlluminatorElementReadiness(Readiness.inMainWindow)
    static let Hittable      = IlluminatorElementReadiness(Readiness.hittable)

    /**
        Implementation for CustomStringConvertible

        - Returns: A string describing which options have been sent
     */
    public var description : String{
        var result = [String]()
        var shift = 0

        // TODO: probably a better way to reduce()
        while let v = Readiness(rawValue: 1 << shift) {
            shift = shift + 1
            if self.contains(IlluminatorElementReadiness(v)){
                result.append("\(v)")
            }
        }
        return "[\(result.joined(separator: ","))]"
    }
}


let defaultReadiness: IlluminatorElementReadiness = [.Exists, .Hittable]

extension XCUIElement {

    /**
        Best effort equality test
        
        this code was adapted from the original javascript implementation of Illuminator
        and it may no longer be relevant.  It is here until we can find a more relevant equality operation
        - Parameter e: The element to compare to this element
        - Returns: Whether the elements are deemed equal
     */
    func equals(_ e: XCUIElement) -> Bool {
        
        // nonexistent elements can't be equal to anything
        guard exists && e.exists else {
            return false
        }
        
        var result = false
        
        let c1 = self.elementType == e.elementType
        let c2 = self.self.label == e.label
        let c3 = self.identifier == e.identifier
        let c4 = self.isHittable == e.isHittable
        let c5 = self.frame == e.frame
        let c6 = self.isEnabled == e.isEnabled
        let c7 = self.accessibilityLabel == e.accessibilityLabel
        let c8 = self.isSelected == e.isSelected
        
        result = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8
        
        return result
    }

    /**
        Swipe in a specified direction until an element is hittable

         - Parameters:
            - target: the element being searched for
            - direction: the swipe direction (the reverse of the scroll direction)
            - failMessage: Text to append to the failure message, indicating the exit condition
            - giveUpCondition: Closure that returns true when the swipe operations should terminate (indicating a failure)
        - Returns: the target element
        - Throws: `IlluminatorError.ElementNotReady` If the target is not found
     */
    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, failMessage: String, giveUpCondition: (XCUIElement, XCUIElement) -> Bool) throws -> XCUIElement  {
        repeat {
            if element.exists {
                if element.isHittable { return element }
            }

            switch direction {
            case UISwipeGestureRecognizerDirection.down:
                swipeDown()
            case UISwipeGestureRecognizerDirection.up:
                swipeUp()
            case UISwipeGestureRecognizerDirection.left:
                swipeLeft()
            case UISwipeGestureRecognizerDirection.right:
                swipeRight()
            default:
                ()
            }
        } while !giveUpCondition(self, element)

        if !element.inMainWindow {
            throw IlluminatorError.elementNotReady(message: "Couldn't find \(element) after \(failMessage)")
        }
        return element
    }

    /**
        Swipe in a specified direction until an element is hittable or a timeout is reached

        - Parameters:
            - target: the element being searched for
            - direction: the swipe direction (the reverse of the scroll direction)
            - withTimeout: the number of seconds to wait before failing
        - Returns: the target element
        - Throws: `IlluminatorError.ElementNotReady` If the target is not found
     */
    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, withTimeout seconds: Double) throws -> XCUIElement {
        let startTime = Date()
        return try swipeTo(target: element, direction: direction, failMessage: "scrolling for \(seconds) seconds") { (_, _) in
            return (0 - startTime.timeIntervalSinceNow) > seconds
        }
    }

    /**
        Swipe in a specified direction until an element is hittable or a maxiumum number of swipes has been reached

        - Parameters:
            - target: the element being searched for
            - direction: the swipe direction (the reverse of the scroll direction)
            - maxSwipes: the number of times to swipe before failing
        - Returns: the target element
        - Throws: `IlluminatorError.ElementNotReady` If the target is not found
     */
    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, maxSwipes: UInt) throws -> XCUIElement {
        var totalSwipes: UInt = 0
        return try swipeTo(target: element, direction: direction, failMessage: "swiping \(maxSwipes) times") { (_, _) in
            totalSwipes = totalSwipes + 1
            return totalSwipes > maxSwipes
        }
    }

    /**
         Drag a line (or rectangle select) within the element

         - Parameters:
             - startLocation: Starting coordinates with normalized offset
             - endLocation: Ending coordinates with normalized offset
             - holdDuration: amount of time to hold before dragging
         - Returns: the element
     */
    func dragLine(_ startLocation: CGVector, endLocation: CGVector, holdDuration: TimeInterval = 0) -> XCUIElement {
        let start = self.coordinate(withNormalizedOffset: startLocation)
        let finish = self.coordinate(withNormalizedOffset: endLocation)
        start.press(forDuration: holdDuration, thenDragTo: finish)
        return self
    }

    /**
         Drag a line (or rectangle select) within the element

         - Parameters:
             - x1: Start X coordinate with normalized offset
             - y1: Start Y coordinate with normalized offset
             - x2: End X coordinate with normalized offset
             - y2: End Y coordinate with normalized offset
             - holdDuration: amount of time to hold before dragging
         - Returns: the element
     */
    func dragLine(_ x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, holdDuration: TimeInterval = 0) -> XCUIElement {
        let start = CGVector(dx: x1, dy: y1)
        let end = CGVector(dx: x2, dy: y2)
        return dragLine(start, endLocation: end, holdDuration: holdDuration)
    }

    /**
        Check the rectangle of an element and see if it is in the main window.
     */
    var inMainWindow: Bool {
        get {
            guard exists else { return false }
            let window = XCUIApplication().windows.element(boundBy: 0)
            return window.frame.contains(self.frame)
        }
    }

    /**
        Throw an exception if an element is not ready for an action
     
        This is an alternative to an XCTFail

        - Parameters:
            - usingCriteria: the readiness criteria to check
            - otherwiseFailWith: text to annotate the exception on failure
        - Returns: the element
        - Throws: `IlluminatorError.ElementNotReady` If the target is not ready
     */
    func ready(usingCriteria desired: IlluminatorElementReadiness, otherwiseFailWith description: String) throws -> XCUIElement {
        let failMessage = { (message: String) -> String in "\(description); element not ready: \(message)" }
        if desired.contains(.Exists) && !exists {
            throw IlluminatorError.elementNotReady(message: failMessage("element does not exist"))
        }

        if desired.contains(.InMainWindow) && !inMainWindow {
            throw IlluminatorError.elementNotReady(message: failMessage("element is not within the bounds of the main window"))
        }

        if desired.contains(.Hittable) && !isHittable {
            throw IlluminatorError.elementNotReady(message: failMessage("element is not hittable"))
        }

        return self
    }

    /**
        Throw an exception if an element is not ready for an action, using default description

         - Parameters:
            - usingCriteria: the readiness criteria to check
         - Returns: the element
         - Throws: `IlluminatorError.ElementNotReady` If the target is not ready
     */

    @discardableResult
    func ready(usingCriteria desired: IlluminatorElementReadiness) throws -> XCUIElement {
        return try ready(usingCriteria: desired, otherwiseFailWith: "Failed readiness check")
    }

    /**
     Throw an exception if an element is not ready for an action, using default description and criteria

     - Returns: the element
     - Throws: `IlluminatorError.ElementNotReady` If the target is not ready
     */
    func ready() throws -> XCUIElement {
        return try ready(usingCriteria: defaultReadiness)
    }

    /**
         Wait a given number of seconds for a readiness condition

         - Parameters:
             - usingCriteria: the readiness criteria to check
             - withTimeout: the number of seconds to wait
         - Returns: the element
         - Throws: `IlluminatorError.ElementNotReady` If the target is not ready
     */
    func whenReady(usingCriteria desired: IlluminatorElementReadiness, withTimeout seconds: Double) throws -> XCUIElement {
        var lastMessage: String? = nil
        // this flow looks strange, but basically we're working around waitForResult()'s exception -- it throws
        // VerificationFailed, and we want ElementNotReady
        do {
            try waitForProperty(seconds, desired: true) {
                do {
                    try $0.ready(usingCriteria: desired)
                    return true
                } catch IlluminatorError.elementNotReady(let message) {
                    lastMessage = message
                    return false
                } catch {
                    return false
                }
            }
            return self
        } catch IlluminatorError.verificationFailed(let failMessage) {
            throw IlluminatorError.elementNotReady(message: lastMessage ?? failMessage)
        }
    }

    /**
         Wait a given number of seconds for a readiness condition

         - Parameters:
             - secondsToWait: the number of seconds to wait
         - Returns: the element
         - Throws: `IlluminatorError.ElementNotReady` If the target is not ready
     */
    func whenReady(_ secondsToWait: Double = 3.0) throws -> XCUIElement {
        return try whenReady(usingCriteria: defaultReadiness, withTimeout: secondsToWait)
    }

    /**
        Wait until an element property reaches a specific value or a timeout is reached

         - Parameters:
             - seconds: the number of seconds to wait
             - desired: the desired value
             - getProperty: a closure that returns the property, given the element
         - Returns: the element
         - Throws: `VerificationFailed` If the property fails to attains the desired value before the timeout is reached
     */

    @discardableResult
    public func waitForProperty<T: WaitForible>(_ seconds: Double, desired: T, getProperty: (XCUIElement) -> T) throws -> XCUIElement {
        try waitForResult(seconds, desired: desired, what: "waitForProperty") { () -> T in
            return getProperty(self)
        }
        return self
    }

    /**
         Wait until an element property reaches a specific value or a timeout is reached

         - Parameters:
             - desired: the desired value
             - getProperty: a closure that returns the property, given the element
         - Returns: the element
         - Throws: `VerificationFailed` If the property is not equal to the desired value
     */

    @discardableResult
    public func assertProperty<T: WaitForible>(_ desired: T, getProperty: (XCUIElement) -> T) throws -> XCUIElement {
        let actual = getProperty(self)
        if desired != actual {
            throw IlluminatorError.verificationFailed(message: "Expected property to be '\(desired)', got '\(actual)'")
         }
        return self
    }
}

