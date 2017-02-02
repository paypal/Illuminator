//
//  String.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

extension String {
    /**
        Get the capture groups from an applied regular expression

        SWIFT 3 version here: http://stackoverflow.com/a/40040472/2063546

        - Parameters:
            - regex: the regex to apply
        - Returns: An array of arrays; the matches, and the capture groups of those matches
     */
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matchesInString(self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map { result.rangeAtIndex($0).location != NSNotFound
                ? nsString.substringWithRange(result.rangeAtIndex($0))
                : ""
            }
        }
    }
}

