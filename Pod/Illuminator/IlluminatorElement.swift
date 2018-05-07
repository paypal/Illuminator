//
//  IlluminatorElement.swift
//  Illuminator
//
//  Created by Ian Katz on 2016-12-12.
//

import XCTest

/**
    These errors control the parsing behavior to generate the element tree
 */
enum AbortIlluminatorTree: Error {
    case backtrack(data: IlluminatorElement?)
    case eof()
    case parseError(badLine: String)
    case doubleDepth(badLine: String)
}

/**
    An IlluminatorElement is a workaround for the shortcomings of XCUIElement -- namely, the ability to inspect an element and its children without causing a test failure or taking the better part of 3 hours to recursively (and safely) check the descendants of the root element.
 
    Author's note: this functionality has become consistently harder to supply as Apple continues to update its automation system.  It currently relies on the format of `.debugDescription`, which the Apple documentation says not to do.  The day Apple releases code that can supply the Illuminator equivalent of `.dumpAccessors()`, this class can disappear.
 */
class IlluminatorElement: Equatable {
    var source = ""                              // input data
    var depth = 0                                // interpretation of whitespace
    var parent: IlluminatorElement?              // linked list
    var children = [IlluminatorElement]()        // tree
    var elementType: XCUIElementType = .other    // tie back to automation elements
    var handle: UInt = 0                         // memory address, probably
    var traits: UInt = 0                         // bit flags, probably
    var x: Double?
    var y: Double?
    var w: Double?
    var h: Double?
    var isMainWindow = false                     // mainWindow is special
    var label: String?                           // accessibility label
    var identifier: String?                      // accessibility identifier
    var value: String?                           // field value
    var placeholderValue: String?                //

    /**
        A UI element is indexed by its label, but that is overridden by its identifier
        - Returns: the most appropriate indexing string for the element
     */
    var index: String? {
        get {
            return identifier ?? label
        }
    }
    
    /**
        The numeric index for this element, as if the element is bound by a numeric index
        - Returns: the best guess for the element's numeric index within its parent collection
     */
    var numericIndex: UInt? {
        get {
            return getNumericIndexMembership().0
        }
    }

    /**
        The numeric index for this element, as if the element is bound by a numeric index
        - Returns: A pair: index of this element, and the total number of elements
     */
    func getNumericIndexMembership() -> (UInt?, UInt) {
        guard let parent = parent else { return (0, 1) }
        let cohort = parent.childrenMatchingType(elementType)
        guard let idx = cohort.index(of: self) else { return (nil, 0) }
        return (UInt(idx), UInt(cohort.count))
    }

    /**
        - Returns: A short summary of the most relevant element information
     */
    func toString() -> String {
        let elementDesc = elementType.toString()
        return "\(elementDesc) - label: \(String(describing: label)) identifier: \(String(describing: identifier)) value: \(String(describing: value))"
    }
    
    /**
        - Returns: An indented multiline summary of the most relevant element information, and its children
     */
    func treeToString() -> String {
        // swift3 let indent = String(repeating: " ", count: depth)
        let indent = String(repeating: " ", count: depth)
        let childrenString = children.map{ $0.toString() }.joined(separator: "")
        return ["\(indent)\(toString())", childrenString].joined(separator: "\n")
    }
    
    /**
        Create an IlluminatorElement from its debug description
        - Parameters:
            - content: one line of `debugDescription` describing an element
        - Returns: An IlluminatorElement, or nil if the parsing fails
     */
    static func fromDebugDescriptionLine(_ content: String) -> IlluminatorElement? {
        // regex crap
        let fc = "([\\d\\.]+)"        // float capture
        let pc = "\\{\(fc), \(fc)\\}" // pair capture
        let innerRE = "([ →]*)([^\\s]+) 0x([\\dabcdef]+): ([^{]*)?((\\{\(pc), \(pc)\\})?(, )?(.*)?)?"
        
        // safely regex capture
        let safeRegex = { (input: String, regex: String, capture: Int) -> String? in
            guard let field = input.matchingStrings(regex)[safe: 0] else { return nil }
            return field[safe: capture]
        }
        
        // safely extract data from the "extra" field at the end
        let safeExtra = { (input: String, label: String) -> String? in safeRegex(input, "\(label): '([^']*)'($|,)", 1) }
        
        // ensure doubles parse
        guard let matches = content.matchingStrings(innerRE)[safe: 0], matches.count > 12 else {
            return nil
        }
        
        // get depth
        let d = (matches[1].characters.count / 2) - 1
        guard d >= 0 else { return nil }
        
        // build return element
        let ret = IlluminatorElement()
        ret.depth        = d
        ret.elementType  = XCUIElementType.fromString(matches[2])
        ret.handle       = strtoul(matches[3], nil, 16)
        ret.x            = Double(matches[safe: 7] ?? "")
        ret.y            = Double(matches[safe: 8] ?? "")
        ret.w            = Double(matches[safe: 9] ?? "")
        ret.h            = Double(matches[safe: 10] ?? "")
        ret.source       = content
        
        let special      = matches[4]
        ret.isMainWindow = special.matchingStrings("Main Window").count == 1
        if let field = safeRegex(special, "traits: (\\d+)", 1),
            let trait = UInt(field) {
            ret.traits = trait
        }
        
        let extras           = matches[12]
        ret.label            = safeExtra(extras, "label")
        ret.identifier       = safeExtra(extras, "identifier")
        ret.value            = safeExtra(extras, "value")
        ret.placeholderValue = safeExtra(extras, "placeholderValue")
        
        return ret
    }
    
    /**
        Create an IlluminatorElement and its children from the lines of the debug description
        - Parameters:
            - parent: The element that is assumed to be the direct ancestor of the current line
            - source: the remaining (un-parsed) lines of `debugDescription`
        - Returns: An IlluminatorElement representing all the information in `source`
        - Throws: `AbortIlluminatorTree.parseError` if the element fails ot parse
        - Throws: `AbortIlluminatorTree.backtrack` if the element cannot be the child of the supplied parent
        - Throws: `AbortIlluminatorTree.eof` if there are no more lines to parse
     */

    @discardableResult
    fileprivate static func parseTreeHelper(_ parent: IlluminatorElement?, source: [String]) throws -> IlluminatorElement {
        guard let line = source.first else { throw AbortIlluminatorTree.eof() }
        
        guard let elem = IlluminatorElement.fromDebugDescriptionLine(line) else {
            throw AbortIlluminatorTree.parseError(badLine: line)
        }

        // process parent
        if let parent = parent {
            guard elem.depth - parent.depth == 1 else { throw AbortIlluminatorTree.backtrack(data: elem) }
            elem.parent = parent
            parent.children.append(elem)
        }
        
        // process children
        do {
            try parseTreeHelper(elem, source: source.tail)
        } catch AbortIlluminatorTree.eof {
            // no problem
        } catch AbortIlluminatorTree.backtrack(let data) {
            if let data = data, let parent = parent {
                // extra backtrack if necessary
                if data.depth - parent.depth < 1 {
                    throw AbortIlluminatorTree.backtrack(data: data)
                }
                
                if data.depth - parent.depth == 1 {
                    // fast forward the choices that occurred during recursion
                    let fastforward = Array(source[source.index(of: data.source)!..<source.count])
                    try parseTreeHelper(parent, source: fastforward)
                }
            }
        }
        return elem
    }
    
    /**
        Create a tree of IlluminatorElements from the relevant section of a debugDescription

        - Parameters:
            - content: the section of `debugDescription` related to the element tree
        - Returns: An IlluminatorElement representing all the information in `content`, or nil
     */
    fileprivate static func parseTree(_ content: String) -> IlluminatorElement? {
        let lines = content.components(separatedBy: "\n")
        guard lines.count > 0 else { return nil }
        
        let elems = lines.map() { (line: String) -> IlluminatorElement? in IlluminatorElement.fromDebugDescriptionLine(line) }
        let actualElems = elems.flatMap{ $0 }
        
        guard elems.count == actualElems.count else {
            for (i, elem) in elems.enumerated() {
                if elem == nil {
                    print("Illuminator BUG while parsing debugDescription line: \(lines[i])")
                }
            }
            return nil
        }
        
        do {
            return try parseTreeHelper(nil, source: lines)
        } catch AbortIlluminatorTree.backtrack {
            print("Somehow got a backtrack error at the top level of tree parsing")
        } catch AbortIlluminatorTree.parseError(let badLine) {
            print("Caught a parse error of \(badLine)")
        } catch {
            print("Caught an error that we didn't throw... somehow")
        }
        return nil
    }
    
    /**
        Create a tree of IlluminatorElements from a debugDescription

        - Parameters:
            - content: the unadulterated `debugDescription` of an XCUIElement
        - Returns: An IlluminatorElement representing the tree information in `content`, or nil
     */
    static func fromDebugDescription(_ content: String) -> IlluminatorElement? {
        let outerRE = "\\n([^:]+):\\n( →.+(\\n .*)*)"
        let matches = content.matchingStrings(outerRE)
        let sections = matches.reduce([String: String]()) { dict, matches in
            var ret = dict
            ret[matches[1]] = matches[2]
            return ret
        }
        guard let section = sections["Element subtree"] else { return nil }
        return parseTree(section)
    }
    
    /**
        Convert an IlluminatorElement to an XCUIElement
        - Parameters:
            - acc: a chain of elements, topmost-first
            - app: the XCUIApplication representing the known root
        - Returns: The XCUIElement representing this element
     */
    fileprivate func toXCUIElementHelper(_ acc: [IlluminatorElement], app: XCUIApplication) -> XCUIElement {
        
        let finish = { (top: XCUIElement) in
            return acc.reduce(app) { (parent: XCUIElement, elem) in elem.toXCUIElementWith(parent: parent) }
        }
        
        guard elementType != XCUIElementType.application else { return finish(app) }
        guard let parent = parent else {
            print("Warning about toXCUIElementHelper not knowing it's done")
            return finish(app)
        }
        return parent.toXCUIElementHelper([self] + acc, app: app)
    }
    
    /**
        Convert an IlluminatorElement to an XCUIElement by indexing the parent XCUIElement with this IlluminatorElement's information
        - Parameters:
            - parent: a chain of elements, topmost-first
        - Returns: The XCUIElement represented by this element
     */
    func toXCUIElementWith(parent p: XCUIElement) -> XCUIElement {
        return p.children(matching: elementType)[index ?? ""]
    }
    
    /**
        Convert an IlluminatorElement to an XCUIElement by traversing up the tree until the XCUIApplication is reached, then derererencing back down
        - Parameters:
            - app: the actual application
        - Returns: The XCUIElement represented by this element
     */
    func toXCUIElement(_ app: XCUIApplication) -> XCUIElement {
        return toXCUIElementHelper([], app: app)
    }
    
    /**
        Get a swift expression (as string) that could be used to get the XCUIElement represented by this element
        - Parameters:
            - acc: a chain of elements, topmost-first
            - appString: the string representing the known root
        - Returns: A copy-pastable swift expression representing this element
     */
    fileprivate func toXCUIElementStringHelper(_ acc: [IlluminatorElement], appString: String) -> String? {
        let finish = { (top: String) -> String? in
            guard let last = acc.last else { return appString }
            guard last.elementType != XCUIElementType.other || last.index != nil else { return nil }
            return acc.reduce(appString) { (parentStr: String, elem) in elem.toXCUIElementStringWith(parentStr) }
            
        }
        
        guard elementType != XCUIElementType.application else { return finish(appString) }
        guard let parent = parent else {
            print("Warning about toXCUIElementStringHelper not knowing it's done: \(toString())")
            return finish(appString)
        }
        return parent.toXCUIElementStringHelper([self] + acc, appString: appString)
    }
    
    /**
        Get a swift expression (as string) that could be used to get the XCUIElement represented by this element by appending this IlluminatorElement's information to the expression for the parent element
        - Parameters:
            - parent: the string representing the parent element
        - Returns: A copy-pastable swift expression representing this element

     */
    func toXCUIElementStringWith(_ parent: String) -> String {
        guard elementType != XCUIElementType.other || index != nil else { return parent }
        guard !isMainWindow else { return parent }
        
        let prefix = parent + ".\(elementType.toElementString())"
        
        // fall back on numeric index
        guard let idx = index else {
            let numericIndexPair = getNumericIndexMembership()

            switch numericIndexPair {
            case (.none, _):
                return "\(prefix).elementAtIndex(-1)"
            case (.some, 0):
                return "\(prefix).FAIL()"
            case (.some, 1):
                return "\(prefix)"
            case (.some(let nidx), _):
                return "\(prefix).elementAtIndex(\(nidx))"
 
            }

        }

        return "\(prefix)[\"\(idx)\"]"
    }
    
    /**
        Get a swift expression (as string) that could be used to get the XCUIElement represented by this element
        - Parameters:
            - appString: the string representing the known root
        - Returns: A copy-pastable swift expression representing this element
     */
    func toXCUIElementString(_ appString: String) -> String? {
        return toXCUIElementStringHelper([], appString: appString)
    }
    
    /**
        Get all children of this element, of the given type
        - Parameters:
            - elementType: the specific type of element to index
        - Returns: An array of elements indexed numerically
     */
    func childrenMatchingType(_ elementType: XCUIElementType) -> [IlluminatorElement] {
        
        return children.reduce([IlluminatorElement]()) { arr, elem in
            guard elem.elementType == elementType else { return arr }
            var ret = arr
            ret.append(elem)
            return ret
        }
    }

    /**
        Get the labeled children of this element, indexed by their label
        - Parameters:
            - elementType: the specific type of element to index
        - Returns: A dictionary of elements indexed by their label
     */
    func childrenMatchingTypeDict(_ elementType: XCUIElementType) -> [String: IlluminatorElement] {
        
        return children.reduce([String: IlluminatorElement]()) { dict, elem in
            guard let idx = elem.index else { return dict }
            guard elem.elementType == elementType else { return dict }
            var ret = dict
            ret[idx] = elem
            return ret
        }
    }
    
    /**
        Returns the result of repeatedly calling `nextPartialResult` with an
        accumulated value initialized to `initialResult` and each element of
        a depth-first search of `self`, in turn, i.e. return
        `nextPartialResult(nextPartialResult(...nextPartialResult(nextPartialResult(initialResult, root),
        child1),...child_n_minus_1), child_n)`.
        - Parameters:
             - initialResult: the specific type of element to index
             - nextPartialResult: a closure that takes the latest initialResult and a tree element, returning a result
        - Returns: The final result
     */
    func reduce<T>(_ initialResult: T, nextPartialResult: (T, IlluminatorElement) throws -> T) rethrows -> T {
        return try children.reduce(nextPartialResult(initialResult, self)) { (acc, nextElem) in
            return try nextElem.reduce(acc, nextPartialResult: nextPartialResult)
        }
    }
    
    
    /**
        Get a list of swift expressions (as strings) that could be used to get the XCUIElements currently shown in the app hierarchy

        These strings are meant to be copy-pastable into test code
     
        - Parameters:
            - appVarname: Whatever the variable representing the XCUIApplication is called in code (e.g. `self.app` or `XCUIApplication()`
            - appDebugDescription: the `debugDescription` string to parse
        - Returns: A list of copy-pastable swift expressions for XCUIElements
     */
    static func accessorDump(_ appVarname: String, appDebugDescription: String) -> [String] {
        guard let parsedTree = IlluminatorElement.fromDebugDescription(appDebugDescription) else { return [] }
        
        let lines = parsedTree.reduce([String?]()) { (acc, elem) in
            let str = elem.toXCUIElementString(appVarname)
            return str == nil ? acc : acc + [str]
        }
        return lines.flatMap({$0})
    }
    
}

extension IlluminatorElement : Hashable {
    var hashValue: Int { return Int(handle) }
}

func ==(lhs: IlluminatorElement, rhs: IlluminatorElement) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

