//
//  XCUIElementQuery.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


extension XCUIElementQuery {
    
    /**
        Return all elements matching a subscript
     
        This works around an Apple problem where elements cannot be accessed if "multiple matches exist" (causing tests to immediately fail)

        - Parameters:
            - label: the accessibilty label to use as a subscript
        - Returns: all elements matching the label
     */
    func subscriptsMatching(_ label: String) -> [XCUIElement] {
        return self.allElementsBoundByAccessibilityElement.reduce([XCUIElement]()) { (acc, elem) in
            print("Checking \(elem) (\(elem.elementType)): \(elem.label)")
            guard elem.label == label else { return acc }
            var nextAcc = acc
            nextAcc.append(elem)
            return nextAcc
        }
    }

    /**
         Do a subscript operation, but throw an exception immediately unless the subscript returns one and only one match

         This works around an Apple problem where elements cannot be accessed if "multiple matches exist" (causing tests to immediately fail).  Instead of failing, we throw a catchable exception

         - Parameters:
            - index: the accessibilty label to use as a subscript
         - Returns: all elements matching the label
     */
    func hardSubscript(_ index: String) throws -> XCUIElement {
        let matchingElements = allElementsBoundByAccessibilityElement.reduce(0) { (acc, elem) in
            guard elem.label == index else { return acc }
            return acc + 1
        }

        switch matchingElements {
        case 0: throw IlluminatorError.elementNotFound(message: "No elements match the label \"\(index)\"")
        case 1: return self[index]
        default: throw IlluminatorError.multipleElementsFound(message: "Multiple elements match the label \"\(index)\"")
        }
    }
    

}

// allow for-in with elements
// http://design.featherless.software/minimal-swift-protocol-conformance/
//
extension XCUIElementQuery: Sequence {
    public typealias Iterator = AnyIterator<XCUIElement>
    public func makeIterator() -> Iterator {
        var index = UInt(0)
        return AnyIterator {
            guard index < self.count else { return nil }
            
            let element = self.element(boundBy: index)
            index = index + 1
            return element
        }
    }
}

/*
 // please figure out how to do this
 extension XCUIElementQuery: CollectionType {
 subscript(index: Index) -> Generator.Element {
 return elementBoundByIndex(index)
 }
 
 var startIndex : Index { return 0 }
 var endIndex : Index { return Index(UInt(count) - 1) }
 
 }
 */

