//
//  IlluminatorApplication.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

/**
    Illuminator applications are a logical grouping for Illuminator screens
 */
public protocol IlluminatorApplication: CustomStringConvertible {
    var testCaseWrapper: IlluminatorTestcaseWrapper { get }
    //var app: XCUIApplication { get }
    var label: String { get }
}

public extension IlluminatorApplication {
    /**
        CustomStringConvertible implementation
        - Returns: The application's name (label)
     */
    var description: String {
        return label
    }
}
