//
//  HomeScreen.swift
//  Illuminator
//
//  Created by Ian Katz on 12/5/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import Illuminator


class HomeScreen: IlluminatorDelayedScreen<AppTestState> {
    
    init (testCaseWrapper t: IlluminatorTestcaseWrapper) {
        super.init(label: "Home", testCaseWrapper: t, screenTimeout: 3)
    }
    
    override var isActive: Bool {
        return app.buttons["Button"].exists
    }
    
    func enterText(what: String) -> IlluminatorActionGeneric<AppTestState> {
        return makeAction() {
            let textField = self.app.otherElements.containingType(.Button,
                identifier:"Button").childrenMatchingType(.TextField).element
            textField.tap()
            textField.typeText(what)
        }
    }

    func verifyText(expected: String) -> IlluminatorActionGeneric<AppTestState> {
        return makeAction() {
            let textField = self.app.otherElements.containingType(.Button, identifier:"Button").childrenMatchingType(.TextField).element
            XCTAssertEqual(textField.value as? String, expected)
        }
    }

    func enterAndVerifyText(what: String) -> IlluminatorActionGeneric<AppTestState> {
        return makeAction([
            enterText(what),
            verifyText(what)
            ])
    }
}



