//
//  Extensions.swift
//  PayPal Business
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest

@available(iOS 9.0, *)
extension XCUIElement {

    // best effort
    func equals(e: XCUIElement) -> Bool {
        
        // nonexistent elements can't be equal to anything
        guard exists && e.exists else {
            return false
        }
        
        var result = false
        XCTAssert(false)
        
        pcall({
            let c1 = self.elementType == e.elementType
            let c2 = self.self.label == e.label
            let c3 = self.identifier == e.identifier
            let c4 = self.hittable == e.hittable
            let c5 = self.frame == e.frame
            let c6 = self.enabled == e.enabled
            let c7 = self.accessibilityLabel == e.accessibilityLabel
            let c8 = self.selected == e.selected
            
            result = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8
        })
        return result
    }
    

    
    func getTree(prefix: String) -> [(String, XCUIElement)] {
    
        let vectors: [XCUIElementType: String] = [
            .Other: "otherElements",
            .ActivityIndicator: "activityIndicators",
            .Alert: "alerts",
            .Button: "buttons",
            .Browser: "browsers",
            .Cell: "cells",
            .CheckBox: "checkBoxes",
            .CollectionView: "collectionViews",
            .ColorWell: "colorWells",
            .ComboBox: "comboBoxes",
            .DatePicker: "datePickers",
            .DecrementArrow: "decrementArrows",
            .Dialog: "dialogs",
            .DisclosureTriangle: "disclosureTriangles",
            .DockItem: "dockItems",
            .Drawer: "drawers",
            .Grid: "grids",
            .Group: "groups",
            .Handle: "handles",
            .HelpTag: "helpTags",
            .Icon: "icons",
            .Image: "images",
            .IncrementArrow: "incrementArrows",
            .Key: "keys",
            .Keyboard: "keyboards",
            .LayoutArea: "layoutAreas",
            .LayoutItem: "layoutItems",
            .LevelIndicator: "levelIndicators",
            .Link: "links",
            .Map: "maps",
            .Matte: "mattes",
            .Menu: "menus",
            .MenuBar: "menuBars",
            .MenuBarItem: "menuBarItems",
            .MenuButton: "menuButtons",
            .MenuItem: "menuItems",
            .NavigationBar: "navigationBars",
            .Outline: "outlines",
            .OutlineRow: "outlineRows",
            .PageIndicator: "pageIndicators",
            .Picker: "pickers",
            .PickerWheel: "pickerWheels",
            .Popover: "popovers",
            .PopUpButton: "popUpButtons",
            .ProgressIndicator: "progressIndicators",
            .RadioButton: "radioButtons",
            .RadioGroup: "radioGroups",
            .RatingIndicator: "ratingIndicators",
            .RelevanceIndicator: "relevanceIndicators",
            .Ruler: "rulers",
            .RulerMarker: "rulerMarkers",
            .ScrollBar: "scrollBars",
            .ScrollView: "scrollViews",
            .SearchField: "searchFields",
            .SecureTextField: "secureTextFields",
            .SegmentedControl: "segmentedControls",
            .Sheet: "sheets",
            .Slider: "sliders",
            .SplitGroup: "splitGroups",
            .Splitter: "splitters",
            .StaticText: "staticTexts",
            .StatusBar: "statusBars",
            .Stepper: "steppers",
            .Switch: "switches",
            .Tab: "tabs",
            .TabBar: "tabBars",
            .TabGroup: "tabGroups",
            .Table: "tables",
            .TableColumn: "tableColumns",
            .TableRow: "tableRows",
            .TextField: "textFields",
            .TextView: "textViews",
            .Timeline: "timelines",
            .Toggle: "toggles",
            .Toolbar: "toolbars",
            .ToolbarButton: "toolbarButtons",
            .ValueIndicator: "valueIndicators",
            .WebView: "webViews",
            .Window: "windows"]
        
        let typesWorthChecking = vectors.filter() { (key, _) in self.descendantsMatchingType(key).count > 0 }
        
        var acc = [(String, XCUIElement)]() // accumulator
        
        // find out if .elements["name"] works instead of .elements[123]
        func canUseStringLabel(elem: XCUIElement, container: XCUIElement) -> Bool {
            return elem.equals(container.childrenMatchingType(elem.elementType)[elem.label])
        }
        
        func getTreeHelper(inout acc: [(String, XCUIElement)], prefix: String, root: XCUIElement) {
            NSLog(prefix)
            acc.append((prefix, root)) // accumulate
            
            //TODO: the catchall types!
            
            // try all children of all explicit types
            for (elemType, propertyName) in typesWorthChecking {
                let allChildren = root.childrenMatchingType(elemType)
                if allChildren.count > 0 {
                    NSLog("Founds \(allChildren.count) children of type \(propertyName) on \(root)")
                    NSLog("")
                    
                    for (i, _) in allChildren.allElementsBoundByIndex.enumerate() {
                        let elem = allChildren.elementBoundByIndex(UInt(i))
                        let index = canUseStringLabel(elem, container: root) ? elem.label : String(i)
                        let newPrefix = "\(prefix).\(propertyName)[\(index)]"
                        getTreeHelper(&acc, prefix: newPrefix, root: elem)
                    }
                }
            }
        }
        getTreeHelper(&acc, prefix: prefix, root: self)
        return acc
    }
    
    func printTree(prefix: String, printFunction: (String) -> ()) {
        let start = NSDate()
        let tree = getTree(prefix)
        printFunction("getTree took \(start.timeIntervalSinceNow) seconds")
        for (accessor, _) in tree {
            printFunction(accessor)
        }
        printFunction("done printing tree")
    }
}