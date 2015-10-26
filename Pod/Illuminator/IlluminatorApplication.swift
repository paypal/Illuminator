//
//  IlluminatorApplication.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

protocol IlluminatorApplication: CustomStringConvertible {
    var app: XCUIApplication { get }
    var label: String { get }
}

extension IlluminatorApplication {
    var description: String {
        get {
            return "\(self.dynamicType) \(self.label)"
        }
    }
}

class IlluminatorIOSApplication: IlluminatorApplication {
    
    private (set) var label: String
    private (set) var app: XCUIApplication
    var state = [String: String]()
    
    init (app: XCUIApplication, label: String) {
        self.app = app
        self.label = label
    }
    
}
