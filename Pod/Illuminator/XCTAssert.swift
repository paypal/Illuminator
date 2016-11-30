//
//  XCTAssert.Swift
//  Extensions
//
//  Created by Boris Erceg on 2/10/15.
//
//

import XCTest

public func XCTAssertFailable(expression: () throws -> Void, errorBlock: ((ErrorType) -> Void)?, file: StaticString = #file, line: UInt = #line) {
    do {
        try expression()
    } catch let error {
        if let errorBlock = errorBlock {
            errorBlock(error)
        } else {
            XCTAssert(false, "\(error)", file: file, line: line)
        }
    }
}
