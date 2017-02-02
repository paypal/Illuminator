//
//  XCUIElementType.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)

// The string representation of the element type
// Comment slashes indicate plurals that are more complicated than adding "s"
let debugStringOfXCUIElementType: [XCUIElementType: String] = [
    .Other: "Other",
    .Application: "Application",
    .ActivityIndicator: "ActivityIndicator",
    .Alert: "Alert",
    .Button: "Button",
    .Browser: "Browser",
    .Cell: "Cell",
    .CheckBox: "CheckBox",   //////////
    .CollectionView: "CollectionView",
    .ColorWell: "ColorWell",
    .ComboBox: "ComboBox",   /////
    .DatePicker: "DatePicker",
    .DecrementArrow: "DecrementArrow",
    .Dialog: "Dialog",
    .DisclosureTriangle: "DisclosureTriangle",
    .DockItem: "DockItem",
    .Drawer: "Drawer",
    .Grid: "Grid",
    .Group: "Group",
    .Handle: "Handle",
    .HelpTag: "HelpTag",
    .Icon: "Icon",
    .Image: "Image",
    .IncrementArrow: "IncrementArrow",
    .Key: "Key",
    .Keyboard: "Keyboard",
    .LayoutArea: "LayoutArea",
    .LayoutItem: "LayoutItem",
    .LevelIndicator: "LevelIndicator",
    .Link: "Link",
    .Map: "Map",
    .Matte: "Matte",
    .Menu: "Menu",
    .MenuBar: "MenuBar",
    .MenuBarItem: "MenuBarItem",
    .MenuButton: "MenuButton",
    .MenuItem: "MenuItem",
    .NavigationBar: "NavigationBar",
    .Outline: "Outline",
    .OutlineRow: "OutlineRow",
    .PageIndicator: "PageIndicator",
    .Picker: "Picker",
    .PickerWheel: "PickerWheel",
    .Popover: "Popover",
    .PopUpButton: "PopUpButton",
    .ProgressIndicator: "ProgressIndicator",
    .RadioButton: "RadioButton",
    .RadioGroup: "RadioGroup",
    .RatingIndicator: "RatingIndicator",
    .RelevanceIndicator: "RelevanceIndicator",
    .Ruler: "Ruler",
    .RulerMarker: "RulerMarker",
    .ScrollBar: "ScrollBar",
    .ScrollView: "ScrollView",
    .SearchField: "SearchField",
    .SecureTextField: "SecureTextField",
    .SegmentedControl: "SegmentedControl",
    .Sheet: "Sheet",
    .Slider: "Slider",
    .SplitGroup: "SplitGroup",
    .Splitter: "Splitter",
    .StaticText: "StaticText",
    .StatusBar: "StatusBar",
    .Stepper: "Stepper",
    .Switch: "Switch", /////
    .Tab: "Tab",
    .TabBar: "TabBar",
    .TabGroup: "TabGroup",
    .Table: "Table",
    .TableColumn: "TableColumn",
    .TableRow: "TableRow",
    .TextField: "TextField",
    .TextView: "TextView",
    .Timeline: "Timeline",
    .Toggle: "Toggle",
    .Toolbar: "Toolbar",
    .ToolbarButton: "ToolbarButton",
    .ValueIndicator: "ValueIndicator",
    .WebView: "WebView",
    .Window: "Window"]

// Reverse lookup of the above dictionary
let theXCUIElementTypeOfDebugString = debugStringOfXCUIElementType.reduce([String: XCUIElementType]()) { (acc, pair) in
    var ret = acc
    ret[pair.1] = pair.0
    return ret
}


extension XCUIElementType {
    
    /**
        Get an element type (enum value) from a string

        - Parameters:
            - description: the string representation of the element type
        - Returns: The type matching the string
     */
    static func fromString(description: String) -> XCUIElementType {
        guard let val = theXCUIElementTypeOfDebugString[description] else { return .Other }
        return val
    }
    
    /**
        Get an element type (enum value) from a string

        - Returns: the string representation of the element type
     */
    func toString() -> String {
        guard let val = debugStringOfXCUIElementType[self] else { return "<Unknown \(self)>" }
        return val
    }
    
    /**
        The XCUIElement string for this element type -- what would be in a query
        
        This is essentially just a plural of the type

        - Returns: the string representation of the element type as used in a query expression
     */
    func toElementString() -> String {
        switch (self) {
        case .CheckBox: return "checkBoxes"
        case .ComboBox: return "comboBoxes"
        case .Switch: return "switches"
        default:
            let capSingular = toString()
            let fixedCase = String(capSingular.characters.prefix(1)).lowercaseString + String(capSingular.characters.dropFirst())
            return "\(fixedCase)s"
        }
    }
}

