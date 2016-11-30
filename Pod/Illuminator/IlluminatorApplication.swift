//
//  IlluminatorApplication.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

public protocol IlluminatorApplication: CustomStringConvertible {
    var testCaseWrapper: IlluminatorTestcaseWrapper { get }
    //var app: XCUIApplication { get }
    var label: String { get }
}

public extension IlluminatorApplication {
    var description: String {
        return "\(self.dynamicType) \(self.label)"
    }
}
