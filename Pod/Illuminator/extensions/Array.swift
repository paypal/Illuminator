//
//  Array.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

extension Array {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    // kind of surprised this isn't in the language already
    // http://stackoverflow.com/a/30593673/2063546
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// Returns the sub-array of the specified index, out of range values ignored
    // kind of surprised this isn't in the language already
    // http://stackoverflow.com/a/36249411/2063546
    subscript(safe bounds: Range<Index>) -> ArraySlice<Element> {
        
        let empty = { self[self.startIndex..<self.startIndex] }
        // swift 3 let lb = bounds.lowerBound
        // swift 3 let ub = bounds.upperBound
        let lb = bounds.startIndex
        let ub = bounds.endIndex
        guard lb < endIndex else { return empty() }
        guard ub >= startIndex else { return empty() }
        
        let lo = Swift.max(startIndex, lb)
        let hi = Swift.min(endIndex, ub)
        
        return self[lo..<hi]
    }
    
    var tail: Array {
        get {
            return Array(dropFirst())
        }
    }
}
