//
//  XCUIElement.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)
public struct IlluminatorElementReadiness {
    var exists: Bool = true
    var inMainWindow: Bool = true
    var hittable: Bool = true

    init(exists ex: Bool = true, inMainWindow mw: Bool = true, hittable hit: Bool = true) {
        exists = ex
        inMainWindow = mw
        hittable = hit
    }

}

let defaultReadiness = IlluminatorElementReadiness(exists: true, inMainWindow: false, hittable: true)

extension XCUIElement {
    
    // best effort
    // this code was adapted from the original javascript implementation of Illuminator
    // and it may no longer be relevant.  It is here until we can find a more relevant equality operation
    func equals(e: XCUIElement) -> Bool {
        
        // nonexistent elements can't be equal to anything
        guard exists && e.exists else {
            return false
        }
        
        var result = false
        
        let c1 = self.elementType == e.elementType
        let c2 = self.self.label == e.label
        let c3 = self.identifier == e.identifier
        let c4 = self.hittable == e.hittable
        let c5 = self.frame == e.frame
        let c6 = self.enabled == e.enabled
        let c7 = self.accessibilityLabel == e.accessibilityLabel
        let c8 = self.selected == e.selected
        
        result = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8
        
        return result
    }

    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, failMessage: String, giveUpCondition: (XCUIElement, XCUIElement) -> Bool) throws {
        repeat {
            switch direction {
            case UISwipeGestureRecognizerDirection.Down:
                swipeDown()
            case UISwipeGestureRecognizerDirection.Up:
                swipeUp()
            case UISwipeGestureRecognizerDirection.Left:
                swipeLeft()
            case UISwipeGestureRecognizerDirection.Right:
                swipeRight()
            default:
                ()
            }
            if element.inMainWindow { return }
        } while !giveUpCondition(self, element)
        throw IlluminatorExceptions.ElementNotReady(message: "Couldn't find \(element) after \(failMessage)")
    }

    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, withTimeout seconds: Double) throws {
        let startTime = NSDate()
        try swipeTo(target: element, direction: direction, failMessage: "scrolling for \(seconds) seconds") { (_, _) in
            return (0 - startTime.timeIntervalSinceNow) < seconds
        }
    }

    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, maxSwipes: UInt) throws {
        var totalSwipes: UInt = 0
        try swipeTo(target: element, direction: direction, failMessage: "swiping \(maxSwipes) times") { (_, _) in
            totalSwipes = totalSwipes + 1
            return totalSwipes > maxSwipes
        }
    }

    // check the rectangle of an element and see if it is in the main window.
    var inMainWindow: Bool {
        get {
            guard exists else { return false }
            let window = XCUIApplication().windows.elementBoundByIndex(0)
            return CGRectContainsRect(window.frame, self.frame)
        }
    }

    // general purpose function for checking that an element is ready for an action
    // in order to throw an illuminator error instead of simply XCTFailing with no info
    func ready(usingCriteria desired: IlluminatorElementReadiness, otherwiseFailWith description: String) throws -> XCUIElement {
        let failMessage = { (message: String) -> String in "\(description); element not ready: \(message)" }
        if desired.exists && !exists {
            throw IlluminatorExceptions.ElementNotReady(message: failMessage("element does not exist"))
        }

        if desired.inMainWindow && !inMainWindow {
            throw IlluminatorExceptions.ElementNotReady(message: failMessage("element is not within the bounds of the main window"))
        }

        if desired.hittable && !hittable {
            throw IlluminatorExceptions.ElementNotReady(message: failMessage("element is not hittable"))
        }

        return self
    }

    func ready(usingCriteria desired: IlluminatorElementReadiness) throws -> XCUIElement {
        return try ready(usingCriteria: desired, otherwiseFailWith: "Failed readiness check")
    }

    func ready() throws -> XCUIElement {
        return try ready(usingCriteria: defaultReadiness)
    }

    // wait for readiness condition for a given number of seconds; throw or return self
    func whenReady(usingCriteria desired: IlluminatorElementReadiness, withTimeout seconds: Double) throws -> XCUIElement {
        try waitForResult(seconds, desired: true, what: "element.ready()") {
            do {
                try self.ready(usingCriteria: desired)
                return true
            } catch {
                return false
            }
        }
        return self
    }

    func whenReady(secondsToWait: Double = 3.0) throws -> XCUIElement {
        return try whenReady(usingCriteria: defaultReadiness, withTimeout: secondsToWait)
    }
}

