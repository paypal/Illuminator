//
//  XCUIElement.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)
/*
 
 It should be noted here that all the extensions here are ported from the
 UIAutomation-based Illuminator code written in JavaScript.  Due to
 limitations in XCTest, they are both impractical (descendentsMatchingType
 taking too long) and unworkable (certain element operations directly fail
 tests rather than throw exceptions).
 
 This code remains here in the hopes that it can be salvaged at some future
 point.
 
 */
extension XCUIElement {
    
    // best effort
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
}

