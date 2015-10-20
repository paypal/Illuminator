//
//  XCUIElement.swift
//  XCUIElement
//
//  Created by Boris Erceg on 20/10/15.
//
//

import XCTest

extension XCUIElement {
    
    var app: XCUIApplication {
        return XCUIApplication()
    }
    
    func verifyVisible(app: XCUIApplication, completion: (visible: Bool)->Void) {
        //TODO
    }
    
    convenience init(app: XCUIApplication, completion: (visible: Bool)->Void) {
        self.init()
        verifyVisible(app, completion: completion)
    }
    
    class func act()->Void {
    
    }
}