//
//  XCUIElementQuery.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)

// allow for-in with elements
// http://design.featherless.software/minimal-swift-protocol-conformance/
//
extension XCUIElementQuery: SequenceType {
    public typealias Generator = AnyGenerator<XCUIElement>
    public func generate() -> Generator {
        var index = UInt(0)
        return AnyGenerator {
            guard index < self.count else { return nil }
            
            let element = self.elementBoundByIndex(index)
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

