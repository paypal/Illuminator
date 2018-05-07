//
//  Array.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

extension Array {
    /**
        The element at the specified index iff it is within bounds, otherwise nil.

        I am surprised this isn't in the language already
        http://stackoverflow.com/a/36249411/2063546

        - Parameters:
            - safe: index of the array to retrieve
        - Returns: the element at that index, or nil
     */
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /**
        The sub-array of the specified range, with out of range values ignored

        - Parameters:
            - safe: bounds of the subarray to retrieve
        - Returns: the subarray, empty if there is no overlap
     */
    subscript(safe bounds: Range<Index>) -> ArraySlice<Element> {
        
        let empty = { self[self.startIndex..<self.startIndex] }
        // swift 3 let lb = bounds.lowerBound
        // swift 3 let ub = bounds.upperBound
        let lb = bounds.lowerBound
        let ub = bounds.upperBound
        guard lb < endIndex else { return empty() }
        guard ub >= startIndex else { return empty() }
        
        let lo = Swift.max(startIndex, lb)
        let hi = Swift.min(endIndex, ub)
        
        return self[lo..<hi]
    }
    
    /**
        All elements of the array except the first one

         - Returns: the subarray
     */
    var tail: Array {
        get {
            return Array(dropFirst())
        }
    }
}
