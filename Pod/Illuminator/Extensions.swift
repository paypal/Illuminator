//
//  Extensions.swift
//  PayPal Business
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

@available(iOS 9.0, *)
/*
 
 It should be noted here that all the extensions here are ported from the 
 UIAutomation-based Illuminator code written in JavaScript.  Due to 
 limitations in XCTest, they are both impractical (descendentsMatchingType
 taking too long) and unworkable (certain element operations directly fail
 tests rather than throw exceptions).
 
 This code remains here in the hopes that it can be salvaged at some future
 point.
 
 */
extension XCUIElement {
    
    // best effort
    func equals(e: XCUIElement) -> Bool {
        
        // nonexistent elements can't be equal to anything
        guard exists && e.exists else {
            return false
        }
        
        var result = false
        
        let c1 = self.elementType == e.elementType
        let c2 = self.self.label == e.label
        let c3 = self.identifier == e.identifier
        let c4 = self.hittable == e.hittable
        let c5 = self.frame == e.frame
        let c6 = self.enabled == e.enabled
        let c7 = self.accessibilityLabel == e.accessibilityLabel
        let c8 = self.selected == e.selected
        
        result = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8
        
        return result
    }
    
    
 }

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


extension String {
    // regex with capture SWIFT 3 version here: http://stackoverflow.com/a/40040472/2063546
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


// allow for-in with elements
// http://design.featherless.software/minimal-swift-protocol-conformance/
//
extension XCUIElementQuery: SequenceType {
    public typealias Generator = AnyGenerator<XCUIElement>
    public func generate() -> Generator {
        var index = UInt(0)
        return anyGenerator {
            guard index < self.count else { return nil }

            let element = self.elementBoundByIndex(index)
            index++
            return element
        }
    }
}


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

let theXCUIElementTypeOfDebugString = debugStringOfXCUIElementType.reduce([String: XCUIElementType]()) { (acc, pair) in
    var ret = acc
    ret[pair.1] = pair.0
    return ret
}


extension XCUIElementType {
    
    static func fromString(_ description: String) -> XCUIElementType {
        guard let val = theXCUIElementTypeOfDebugString[description] else { return .Other }
        return val
    }
    
    func toString() -> String {
        guard let val = debugStringOfXCUIElementType[self] else { return "<Unknown \(self)>" }
        return val
    }
    
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




/*
 // please figure out how to do this
extension XCUIElementQuery: CollectionType {
    subscript(index: Index) -> Generator.Element {
        return elementBoundByIndex(index)
    }
    
    var startIndex : Index { return 0 }
    var endIndex : Index { return Index(UInt(count) - 1) }
    
}
 */

