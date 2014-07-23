

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// General-purpose functions
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * shortcut function to get target, sets _accessor
 */
function target() {
    var ret = UIATarget.localTarget();
    ret._accessor = "target()";
    return ret;
}

function mainWindow() {
    var ret = UIATarget.localTarget().frontMostApp().mainWindow();
    ret._accessor = "mainWindow()";
    return ret;
}

function delay(seconds) {
    target().delay(seconds);
}

function getTime() {
    return (new Date).getTime() / 1000;
}

/**
 * Extend an object prototype with an associative array of properties
 *
 * @param baseClass a javascript class
 * @param properties an associative array of properties to add to the prototype of baseClass
 */
function extendPrototype(baseClass, properties) {
    for (var p in properties) {
        baseClass.prototype[p] = properties[p];
    }
}

/**
 * Return true if the element is usable -- not some form of nil
 *
 * @param elem the element to check
 */
function isNotNilElement(elem) {
    if (elem === undefined) return false;
    if (elem === null) return false;
    if (elem.isNotNil) return elem.isNotNil();
    return elem.toString() != "[object UIAElementNil]";
}

/**
 * Return true if a selector is "hard" -- referring to one and only one element by nature
 */
function isHardSelector(selector) {
    switch (typeof selector) {
        case "function": return true;
        case "string": return true;
        default: return false;
    }
}

/**
 * "constructor" for UIAElementNil
 *
 * UIAutomation doesn't give us access to the UIAElementNil constructor, so do it our own way
 */
function newUIAElementNil() {
    return UIATarget.localTarget().frontMostApp().windows().firstWithPredicate("name == 'x' and name != 'x'");
}


/**
 * Wait for a function to return a value (i.e. not throw an exception)
 *
 * Execute a function repeatedly.  If it returns a value, return that value.
 * If the timeout is reached, re-raise the exception that the function raised.
 * Guaranteed to execute once and only once after timeout has passed, ensuring
 * that the function is given its full allotted time (2 runs minimum if only exceptions are thrown)
 *
 * @param callerName string name of calling function for logging/erroring purposes
 * @param timeout the timeout in seconds
 * @param functionReturningValue the function to execute.  can return anything.
 */
function waitForReturnValue(timeout, functionName, functionReturningValue) {
    var myGetTime = function () {
        return (new Date).getTime() / 1000;
    }

    switch (typeof timeout) {
    case "number": break;
    default: throw "waitForReturnValue got a bad timeout type: (" + (typeof timeout) + ") " + timeout;
    }

    var stopTime = myGetTime() + timeout;
    var caught = null;


    for (var now = myGetTime(), runsAfterTimeout = 0; now < stopTime || runsAfterTimeout < 1; now = myGetTime()) {
        if (now >= stopTime) {
            ++runsAfterTimeout;
        }

        try {
            return functionReturningValue();
        } catch (e) {
            caught = e;
        }
        delay(0.1); // max 10 Hz
    }

    throw functionName + " failed by timeout after " + timeout + " seconds: " + caught;
}


/**
 * return unique elements (based on UIAElement.equals()) from a {key: element} object
 *
 * @param elemObject an object containing UIAElements keyed on strings
 */
function getUniqueElements(elemObject) {
    var ret = {};
    for (var i in elemObject) {
        var elem = elemObject[i];
        var found = false;
        // add elements to return object if they are not already there (via equality)
        for (var j in ret) {
            if (ret[j].equals(elem)) {
                found = true;
                break;
            }
        }

        if (!found) {
            ret[i] = elem;
        }
    }
    return ret;
}


/**
 * Get one element from a selector result
 */
function getOneCriteriaSearchResult(callerName, elemObject, originalCriteria, allowZero) {
    // assert that there is only one element
    var uniq = getUniqueElements(elemObject);
    var size = Object.keys(elemObject).length;
    if (size > 1 || size == 0 && !allowZero) {
        var msg = callerName + ": expected 1 element";
        if (originalCriteria !== undefined) {
            msg += " from selector " + JSON.stringify(originalCriteria);
        }
        msg += ", received " + size.toString();
        if (size > 0) {
            msg += " {";
            for (var k in elemObject) {
                msg += "\n    " + k + ": " + elemObject[k].toString();
            }
            msg += "\n}";
        }
        throw msg;
    }

    // they're all the same, so return just one
    for (var k in elemObject) {
        UIALogger.logDebug("Selector found object with canonical name: " + k);
        return elemObject[k];
    }
    return newUIAElementNil();
}

/**
 * Resolve an expression to a set of UIAElements
 *
 * Criteria can be one of the following:
 * 1. An object of critera to satisfy UIAElement..find() .
 * 2. An array of objects containing UIAElement.find() criteria; elem = UIAElement.find(arr[0])[0..n].find(arr[1])...
 *
 * @param criteria as described above
 * @param parentElem a UIAElement from which the search for elements will begin
 * @param elemAccessor string representation of the accessor required to get the parentElem
*/
function getElementsFromCriteria(criteria, parentElem, elemAccessor) {
    if (parentElem === undefined) {
        parentElem = target();
        elemAccessor = parentElem._accessor;
    }

    if (elemAccessor === undefined) {
        elemAccessor = "<root elem>";
    }

    // perform a find in several stages
    var segmentedFind = function (criteriaArray, initialElem, initialAccessor) {
        var intermElems = {};
        intermElems[initialAccessor] = initialElem; // intermediate elements
        // go through all criteria
        for (var i = 0; i < criteriaArray.length; ++i) {
            var tmp = {};
            // expand search on each intermediate element using current criteria
            for (var k in intermElems) {
                var newFrontier = intermElems[k].find(criteriaArray[i], k);
                // merge results with temporary storage
                for (var f in newFrontier) {
                    tmp[f] = newFrontier[f];
                }
            }
            // move unique elements from temporary storage into loop variable
            intermElems = getUniqueElements(tmp);
        }
        return intermElems;
    }

    // search in the appropriate way
    if (!(criteria instanceof Array)) {
        criteria = [criteria];
    }

    try {
        UIATarget.localTarget().pushTimeout(0);
        return segmentedFind(criteria, parentElem, elemAccessor);
    } catch (e) {
        throw e;
    } finally {
        UIATarget.localTarget().popTimeout();
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Object prototype functions
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * type a string in a given text field
 *
 * @param text the string to type
 * @param clear boolean value of whether to clear the text field first
 */
var typeString = function (text, clear) {
    text = text.toString(); // force string argument to actual string

    // make sure we can type (side effect: brings up keyboard)
    if (!this.checkIsEditable(2)) {
        throw "typeString couldn't get the keyboard to appear for element " + this.toString() + " with name '" + this.name() + "'";
    }

    var kb, db; // keyboard, deleteButton
    var seconds = 2;
    var waitTime = 0.25;
    var maxAttempts = seconds / waitTime;
    var noSuccess = true;
    var failMsg = null;

    kb = target().frontMostApp().keyboard();

    // attempt to get a successful keypress several times -- using the first character
    // this is a hack for iOS 6.x where the keyboard is sometimes "visible" before usable
    while ((clear || noSuccess) && 0 < maxAttempts--) {
        try {

            // handle clearing
            if (clear) {
                db = kb.buttons()["Delete"];
                if (!db.isNotNil()) db = kb.keys()["Delete"]; // compatibilty hack

                // touchAndHold doesn't work without this next line... not sure why :(
                db.tap();
                clear = false; // prevent clear on next iteration
                db.touchAndHold(3.7);

            }

            if (text.length !== 0) {
                kb.typeString(text.charAt(0));
            }

            noSuccess = false; // here + no error caught means done
        }
        catch (e) {
            failMsg = e;
            UIATarget.localTarget().delay(waitTime);
        }
    }

    // report any errors that prevented success
    if (0 > maxAttempts && null !== failMsg) throw "typeString caught error: " + failMsg.toString();

    // now type the rest of the string
    try {
        if (text.length > 0) kb.typeString(text.substr(1));
    } catch (e) {
        if (-1 == e.toString().indexOf(" failed to tap ")) throw e;

        UIALogger.logDebug("Retrying keyboard action, typing slower this time");
        this.typeString("", true);
        kb.setInterKeyDelay(0.2);
        kb.typeString(text);
    }

};

/**
 * Set the value of a date text field by manipulating the picker wheels
 *
 * All values are numeric and (should) work across languages.  All values are optional.
 *
 * @param year optional integer
 * @param month optional integer
 * @param day optional integer
 */
var pickDate = function (year, month, day) {
    // make sure we can type (side effect: brings up picker)
    if (!this.checkIsPickable(2)) {
        throw "pickDate couldn't get the picker to appear for element " + this.toString() + " with name '" + this.name() + "'";
    }

    var wheel = target().frontMostApp().windows()[1].pickers()[0].wheels();
    if (year !== undefined) wheel[2].selectValue(year.toString());
    if (month !== undefined) wheel[0].selectValue(wheel[0].values()[month - 1]); // read localized value, set that value
    if (day !== undefined) wheel[1].selectValue(day.toString());
};



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Object prototype extensions
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


extendPrototype(UIAElementNil, {
    isNotNil: function () {
        return false;
    },
    isVisible: function () {
        return false;
    }
});


extendPrototype(UIAElementArray, {
    /**
     * Same as withName, but takes a regular expression
     * @param pattern string regex
     */
    withNameRegex: function (pattern) {
        var ret = [];
        for (var i = 0; i < this.length; ++i) {
            var elem = this[i];
            if (elem && elem.isNotNil && elem.isNotNil() && elem.name() && elem.name().match(pattern) !== null) {
                ret.push(elem);
            }
        }
        return ret;
    },

    /**
     * Same as firstWithName, but takes a regular expression
     * @param pattern string regex
     */
    firstWithNameRegex: function (pattern) {
        for (var i = 0; i < this.length; ++i) {
            var elem = this[i];
            if (elem && elem.isNotNil && elem.isNotNil() && elem.name()) {
                if (elem.name().match(pattern) !== null) return elem;
            }
        }
        return newUIAElementNil();
    }
});


extendPrototype(UIAElement, {

    /**
     * shortcut function: if UIAutomation creates this element, then it must not be nil
     */
    isNotNil: function () {
        return true;
    },

    /*
     * A note on what a "selector" is:
     *
     * It can be one of 4 things.
     * 1. A lookup function that takes a base element as an argument and returns another UIAElement.
     * 2. A string that contains an expression (starting with "element.") that returns another UIAElement
     * 3. An object containing critera to satisfy UIAElement.find() .
     * 4. An array of objects containing UIAElement.find() criteria; elem = mainWindow.find(arr[0]).find(arr[1])...
     *
     * Selector types 1 and 2 are considered "hard" selectors -- they can return at most one element
     */

    /**
     * get (possibly several) child elements from Criteria, or none
     *
     * NOTE that this function does not take a selector, just criteria
     * @param criteria
     */
    getChildElements: function (criteria) {
        if (isHardSelector(criteria)) throw "getChildElements got a hard selector, which cannot return multiple elements";
        criteria = this.preProcessSelector(criteria);
        var accessor = this._accessor === undefined ? "<unknown>" : this._accessor;
        return getElementsFromCriteria(criteria, this, accessor);
    },

    /**
     *  Common behavior for getting one child element from a selector
     *
     * @param callerName string the name of the calling function, for logging purposes
     * @param selector the selector to use
     * @param allowZero boolean -- if true, failing selector returns UIAElementNil; if false, throw
     */
    _getChildElement: function (callerName, selector, allowZero) {
        switch(typeof selector) {
        case "function":
            return this.preProcessSelector(selector)(this); // TODO: guarantee isNotNil ?
        case "object":
            return getOneCriteriaSearchResult(callerName, this.getChildElements(selector), selector, allowZero);
        case "string":
            // wrapper function for lookups, only return element if element is visible
            var visible = function (elem) {
                return elem.isVisible() ? elem : newUIAElementNil();
            }
            var element = this;
            return eval(selector);
        default:
            throw caller + " received undefined input type of " + (typeof selector).toString();
        }
    },

    /**
     *  Get one child element from a selector, or UIAElementNil
     * @param selector the selector to use
     */
    getChildElement: function (selector) {
        return this._getChildElement("getChildElement", selector, true);
    },

    /**
     *  Get one and only one child element from a selector, or throw
     * @param selector the selector to use
     */
    getOneChildElement: function (selector) {
        return this._getChildElement("getOneChildElement", selector, false);
    },

    /**
     * Preprocess a selector
     *
     * This function in the prototype should be overridden by an application-specific function.
     * It allows you to rewrite critera or wrap lookup functions to enable additional functionality.
     *
     * @param selector - a function or set of criteria
     * @return selector
     */
    preProcessSelector: function (selector) {
        return selector;
    },


    /**
     * Equality operator
     *
     * Properly detects equality of 2 UIAElement objects
     * - Can return false positives if 2 elements (and ancestors) have the same name, type, and rect()
     * @param elem2 the element to compare to this element
     * @param maxRecursion a recursion limit to observe when checking parent element equality (defaults to -1 for infinite)
     */
    equals: function (elem2, maxRecursion) {
        maxRecursion = maxRecursion === undefined ? -1 : maxRecursion;
        if (this == elem2) return true; // shortcut when x == x
        if (null === elem2) return false; // shortcut when one is null
        if (!isNotNilElement(this) || !isNotNilElement(elem2)) return !isNotNilElement(this) && !isNotNilElement(elem2); // both nil or neither
        if (this.toString() != elem2.toString()) return false; // element type
        if (this.name() != elem2.name()) return false;
        if (JSON.stringify(this.rect()) != JSON.stringify(elem2.rect())) return false; // possible false positives!
        if (0 == maxRecursion) return true; // stop recursing?
        if (-100 == maxRecursion) UIALogger.logWarning("Passed 100 recursions in UIAElement.equals");
        return this.parent() === null || this.parent().equals(elem2.parent(), maxRecursion - 1); // check parent elem
    },

    /**
     * General-purpose reduce function
     *
     * Applies the callback function to each node in the element tree starting from the current element.
     *
     * Callback function takes (previousValue, currentValue <UIAElement>, accessor_prefix, toplevel <UIAElement>)
     *     where previousValue is: initialValue (first time), otherwise the previous return from the callback
     *           currentValue is the UIAElement at the current location in the tree
     *           accessor_prefix is the code to access this element from the toplevel element
     *           toplevel is the top-level element on which this reduce function was called
     *
     * @param callback function
     * @param initialValue (any type, dependent on callback)
     * @param visibleOnly prunes the search tree to visible elements only
     */
    _reduce: function (callback, initialValue, visibleOnly) {
        var reduce_helper = function (elem, acc, prefix) {
            var scalars = ["frontMostApp", "navigationBar", "mainWindow", "keyboard", "popover", "tabBar", "toolbar"];
            var vectors = ["activityIndicators", "buttons", "cells", "collectionViews", "images","keys",
                           "links", "navigationBars", "pageIndicators", "pickers", "progressIndicators",
                           "scrollViews", "searchBars", "secureTextFields", "segmentedControls", "sliders",
                           "staticTexts", "switches", "tabBars", "tableViews", "textFields", "textViews",
                           "toolbars", "webViews", "windows"];

            // function to visit an element, and add it to an array of what was discovered
            var accessed = [];
            var visit = function (someElem, accessor, onlyConsiderNew) {
                // filter invalid
                if (undefined === someElem) return;
                if (!someElem.isNotNil()) return;

                // filter already visited (in cases where we care)
                if (onlyConsiderNew) {
                    for (var i = 0; i < accessed.length; ++i) {
                        if (accessed[i].equals(someElem, 0)) return;
                    }
                }
                accessed.push(someElem);

                // filter based on visibility
                if (visibleOnly && !someElem.isVisible()) return;
                acc = reduce_helper(someElem, callback(acc, someElem, accessor, this), accessor);
            };

            // try to access an element by name instead of number
            var getNamedIndex = function (someArray, numericIndex) {
                var e = someArray[numericIndex];
                var name = e.name();
                if (name !== null && e.equals(someArray.firstWithName(name), 0)) return '"' + name + '"';
                return numericIndex;
            }

            // visit scalars
            for (var i = 0; i < scalars.length; ++i) {
                if (undefined === elem[scalars[i]]) continue;
                if (elem.toString() == "[object UIAApplication]" && scalars[i] == "navigationBar") continue; // prevent dupe
                visit(elem[scalars[i]](), prefix + "." + scalars[i] + "()", false);
            }

            // visit the elements of the vectors
            for (var i = 0; i < vectors.length; ++i) {
                if (undefined === elem[vectors[i]]) continue;
                var elemArray = elem[vectors[i]]();
                if (undefined === elemArray) continue;
                for (var j = 0; j < elemArray.length; ++j) {
                    var newElem = elemArray[j];
                    var preventDuplicates = vectors[i] == "windows"; // otherwise we get both .mainWindow() and .windows()[0]
                    visit(newElem, prefix + "." + vectors[i] + "()[" + getNamedIndex(elemArray, j) + "]", preventDuplicates);
                }
            }

            // visit any un-visited items
            var elemArray = elem.elements()
            for (var i = 0; i < elemArray.length; ++i) {
                visit(elemArray[i], prefix + ".elements()[" + getNamedIndex(elemArray, i) + "]", true);
            }
            return acc;
        };

        var t0 = getTime();
        UIATarget.localTarget().pushTimeout(0);
        try {
            return reduce_helper(this, initialValue, "");
        } catch(e) {
            throw e;
        } finally {
            var totalTime = Math.round((getTime() - t0) * 10) / 10;
            UIALogger.logDebug("_reduce operation on " + this + " completed in " + totalTime + " seconds");
            UIATarget.localTarget().popTimeout();
        }

    },

    /**
     * Reduce function
     *
     * Applies the callback function to each node in the element tree starting from the current element.
     *
     * Callback function takes (previousValue, currentValue <UIAElement>, accessor_prefix, toplevel <UIAElement>)
     *     where previousValue is: initialValue (first time), otherwise the previous return from the callback
     *           currentValue is the UIAElement at the current location in the tree
     *           accessor_prefix is the code to access this element from the toplevel element
     *           toplevel is the top-level element on which this reduce function was called
     */
    reduce: function (callback, initialValue) {
        return this._reduce(callback, initialValue, false);
    },

    /**
     * Reduce function
     *
     * Applies the callback function to each visible node in the element tree starting from the current element.
     *
     * Callback function takes (previousValue, currentValue <UIAElement>, accessor_prefix, toplevel <UIAElement>)
     *     where previousValue is: initialValue (first time), otherwise the previous return from the callback
     *           currentValue is the UIAElement at the current location in the tree
     *           accessor_prefix is the code to access this element from the toplevel element
     *           toplevel is the top-level element on which this reduce function was called
     */
    reduceVisible: function (callback, initialValue) {
        return this._reduce(callback, initialValue, true);
    },

    /**
     * Find function
     *
     * Find elements by given criteria.  Known criteria options are:
     *  * UIAType: the class name of the UIAElement
     *  * nameRegex: a regular expression that will be applied to the name() method
     *  * rect, hasKeyboardFocus, isEnabled, isValid, label, name, value:
     *        these correspond to the values of the UIAelement methods of the same names.
     *
     * Return associative array {accessor: element} of results
     */
    find: function (criteria, varName) {
        if (criteria === undefined) {
            UIALogger.logWarning("No criteria passed to find function, so assuming {} and returning all elements");
            criteria = {};
        }
        varName = varName === undefined ? "<root element>" : varName;
        var visibleOnly = criteria.isVisible === true;

        var knownOptions = {UIAType: 1, rect: 1, hasKeyboardFocus: 1, isEnabled: 1, isValid: 1,
                            label: 1, name: 1, nameRegex: 1, value: 1, isVisible: 1};

        // helpful check, mostly catching capitalization errors
        for (var k in criteria) {
            if (knownOptions[k] === undefined) {
                UIALogger.logWarning(this.toString() + ".find() received unknown criteria field '" + k + "' "
                                     + "(known fields are " + Object.keys(knownOptions).join(", ") + ")");

            }
        }

        var c = criteria;
        // don't consider isVisible here, because we do it in this._reduce
        var collect_fn = function (acc, elem, prefix, _) {
            if (c.UIAType !== undefined && "[object " + c.UIAType + "]" != elem.toString()) return acc;
            if (c.rect !== undefined && JSON.stringify(c.rect) != JSON.stringify(elem.rect())) return acc;
            if (c.hasKeyboardFocus !== undefined && c.hasKeyboardFocus != elem.hasKeyboardFocus()) return acc;
            if (c.isEnabled !== undefined && c.isEnabled != elem.isEnabled()) return acc;
            if (c.isValid !== undefined && c.isValid !== elem.isValid()) return acc;
            if (c.label !== undefined && c.label != elem.label()) return acc;
            if (c.name !== undefined && c.name != elem.name()) return acc;
            if (c.nameRegex !== undefined && (elem.name() === null || elem.name().match(c.nameRegex) === null)) return acc;
            if (c.value !== undefined && c.value != elem.value()) return acc;

            acc[varName + prefix] = elem;
            elem._accessor = varName + prefix; // annotate the element with its accessor
            return acc;
        }

        return this._reduce(collect_fn, {}, visibleOnly);
    },

    /**
     * Get a list of valid element references in .js format for copy/paste use in code
     * @param varname is used as the first element in the canonical name
     * @param visibleOnly boolean whether to only get visible elements
     * @return array of strings
     */
    getChildElementReferences: function (varName, visibleOnly) {
        varName = varName === undefined ? "<root element>" : varName;

        var collect_fn = function (acc, _, prefix, __) {
            acc.push(varName + prefix)
            return acc;
        };

        return this._reduce(collect_fn, [], visibleOnly);
    },


    /**
     * Get the valid child element references in .js format as one string, delimited by newlines
     *
     * @param varname is used as the first element in the canonical name
     * @param visibleOnly boolean whether to only get visible elements
     */
    elementReferenceDump: function (varName, visibleOnly) {
        varName = varName === undefined ? "<root element>" : varName;
        var title = "elementReferenceDump";
        if (visibleOnly === true) {
            title += " (of visible elements)";
            switch (this.toString()) {
            case "[object UIATarget]":
            case "[object UIAApplication]":
                break;
            default:
                if (this.isVisible()) return title + ": <none, " + varName + " is not visible>";
            }
        }
        var ret = title + " of " + varName + ":\n" + varName + "\n";
        var refArray = this.getChildElementReferences(varName, visibleOnly);
        // shorten references if we can
        for (var i = 0; i < refArray.length; ++i) {
            ret += refArray[i].replace("target().frontMostApp().mainWindow()", "mainWindow()") + "\n";
        }
        return ret;
    },


    /**
     * Wait for a function on this element to return a value
     *
     * @param timeout the timeout in seconds
     * @param functionName the calling function, for logging purposes
     * @param propertyName the name of the property being checked (method name)
     * @param desiredValue the value that will trigger the return of this wait operation, or array of acceptable values
     * @param actualValueFunction optional function that overrides this[propertyName]()
     */
    _waitForPropertyOfElement: function (timeout, functionName, propertyName, desiredValue, actualValueFunction) {
        // actualValueFunction overrides default behavior: just grab the property name and call it
        if (undefined === actualValueFunction) {
            actualValueFunction = function (obj) {
                if (undefined === obj[propertyName]) throw "Couldn't get property '" + propertyName + "' of object " + obj;
                return obj[propertyName]();
            }
        }

        var desiredValues = desiredValue;
        if (!(desiredValue instanceof Array)) {
            desiredValues = [desiredValue];
        }

        var thisObj = this;
        var wrapFn = function () {
            var actual = actualValueFunction(thisObj);
            for (var i = 0; i < desiredValues.length; ++i) {
                if (desiredValues[i] === actual) return;
            }
            var msg = "Value of property '" + propertyName + "' is (" + (typeof actual) + ") '" + actual + "'";
            if (desiredValue instanceof Array) {
                msg += ", not one of the desired values ('" + desiredValues.join("', '") + "')";
            } else {
                msg += ", not the desired value (" + (typeof desiredValue) + ") '" + desiredValue + "'";
            }
            throw msg;
        };

        waitForReturnValue(timeout, functionName, wrapFn);
        return this;
    },

    /**
     * Wait for a function on this element to return a value
     *
     * @param timeout the timeout in seconds
     * @param functionName the calling function, for logging purposes
     * @param inputDescription string describing the input data, for logging purposes (i.e. what isDesiredValue is looking for)
     * @param returnName the name of the value being returned, for logging purposes
     * @param isDesiredValueFunction function that determines whether the returned value is acceptable
     * @param actualValueFunction function that retrieves value from element
     */
    _waitForReturnFromElement: function (timeout, functionName, inputDescription, returnName, isDesiredValueFunction, actualValueFunction) {
        var thisObj = this;
        var wrapFn = function () {
            var actual = actualValueFunction(thisObj);
            // TODO: possibly wrap this in try/catch and use it to detect criteria selectors that return multiples
            if (isDesiredValueFunction(actual)) return actual;
            throw "No acceptable value for " + returnName + " was returned from " + inputDescription;
        };

        return waitForReturnValue(timeout, functionName, wrapFn);
    },

    /**
     * Wait for a selector to produce an element (or lack thereof) in the desired existence state
     *
     * @param timeout the timeout in seconds
     * @param existenceState boolean of whether we want to find an element (vs find no element)
     * @param description the description of what element we are trying to find
     * @param selector the selector for the element whose existence will be checked
     */
    waitForChildExistence: function (timeout, existenceState, description, selector) {
        if (undefined === selector) throw "waitForChildExistence: No selector was specified";

        var actualValFn = function (thisObj) {
            // if we expect existence, try to get the element.
            if (existenceState) return thisObj.getChildElement(selector);

            // else we need to check on the special case where criteria might fail by returning multiple elements
            if (!isHardSelector(selector)) {
                // criteria should return 0 elements -- we will check for 2 elements after
                return {"criteriaResult": thisObj.getChildElements(selector)};
            }

            // functions should error or return a nil element
            try {
                return {"functionResult": thisObj.getChildElement(selector)};
            } catch (e) {
                return {"functionResult": newUIAElementNil()};
            }
        };

        var isDesired = function (someObj) {
            // if desired an element, straightforward case
            if (existenceState) return isNotNilElement(someObj);

            // else, make sure we got 0 elements
            if (!isHardSelector(selector)) {
                var result = someObj.criteriaResult;
                switch (Object.keys(result).length) {
                case 0: return true;
                case 1: return false;
                default:
                    // TODO: throw specific error here: "setup error discovered at runtime"
                    UIALogger.logWarning("Selector (criteria) returned " + Object.keys(result).length + " results, not 0: " + JSON.stringify(result));
                    return false;
                }
            }

            // functions should return a nil element
            return !isNotNilElement(someObj.functionResult);
        };

        var inputDescription;
        if (isHardSelector(selector)) {
            inputDescription = selector;
        } else {
            inputDescription = JSON.stringify(selector);
        }

        try {
            UIATarget.localTarget().pushTimeout(0);
            return this._waitForReturnFromElement(timeout, "waitForChildExistence", inputDescription, description, isDesired, actualValFn);
        } catch (e) {
            throw e;
        } finally {
            UIATarget.localTarget().popTimeout();
        }
    },

    /**
     * Wait until at least one selector in an associative array of selectors returns a valid lookup.
     *
     *  Return an associative array of {key: <element found>, elem: <the element that was found>}
     *
     * @param timeout the timeout in seconds
     * @param selectors associative array of {label: selector}
     */
    waitForChildSelect: function (timeout, selectors) {
        if ((typeof selectors) != "object") throw "waitForChildSelect expected selectors to be an object, but got: " + (typeof selectors);

        // composite find function
        var findAll = function (thisObj) {
            var ret = {};
            for (var selectorName in selectors) {
                var selector = selectors[selectorName];
                try {
                    var el = thisObj.getChildElement(selector);
                    if (isNotNilElement(el)) {
                        ret[selectorName] = el;
                    }
                }
                catch (e) {
                    // ignore
                }
            }
            return ret;
        };

        var foundAtLeastOne = function (resultObj) {
            return 0 < Object.keys(resultObj).length;
        };

        var description = "any selector";

        // build a somewhat readable list of the inputs
        var inputArr = [];
        for (var selectorName in selectors) {
            var selector = selectors[selectorName];

            if (isHardSelector(selector)) {
                inputArr.push(selectorName + ": " + selector);
            } else {
                inputArr.push(selectorName + ": " + JSON.stringify(selector));
            }
        }

        var inputDescription = "selectors {" + inputArr.join(", ") + "}";

        try {
            UIATarget.localTarget().pushTimeout(0);
            return this._waitForReturnFromElement(timeout, "waitForChildSelect", inputDescription, description, foundAtLeastOne, findAll);
        } catch (e) {
            throw e;
        } finally {
            UIATarget.localTarget().popTimeout();
        }

    },

    /**
     * Wait for this element to become visible
     *
     * @param timeout the timeout in seconds
     * @param visibility boolean whether we want the item to be visible
     */
    waitForVisibility: function (timeout, visibility) {
        return this._waitForPropertyOfElement(timeout, "waitForVisibility", "isVisible", visibility ? 1 : 0);
    },

    /**
     * Wait for this element to become valid
     *
     * @param timeout the timeout in seconds
     * @param validity boolean whether we want the item to be valid
     */
    waitForValidity: function (timeout, validity) {
        return this._waitForPropertyOfElement(timeout, "waitForValidity", "checkIsValid", validity ? 1 : 0);
    },

    /**
     * Wait for this element to have the given name
     *
     * @param timeout the timeout in seconds
     * @param name string the name we are waiting for
     */
    waitForName: function (timeout, name) {
        return this._waitForPropertyOfElement(timeout, "waitForName", "name", name);
    },

    /**
     * A shortcut for waiting an element to become visible and tap.
     * @param timeout the timeout in seconds
     */
    vtap: function (timeout) {
        timeout = timeout === undefined ? 5 : timeout;
        this.waitForVisibility(timeout, true);
        this.tap();
    },

    /**
     * A shortcut for scrolling to a visible item and and tap.
     * @param timeout the timeout in seconds
     */
    svtap: function (timeout) {
        timeout = timeout === undefined ? 5 : timeout;
        try {
            this.scrollToVisible();
        } catch (e) {
            // iOS 6 hack when no scrolling is needed
            if (e.toString() != "scrollToVisible cannot be used on the element because it does not have a scrollable ancestor.") {
                throw e;
            }
        }
        this.tap();
    },

    /**
     * Check whether tapping this element produces another element.  Used for supporting other checkX functions
     *
     * (this) - the element that we will tap
     * @param callerName - the name of the function that calls this function, used for logging
     * @param elementLookup - a function that returns the element we are trying to produce
     * @param elementDescription - describe the element we are trying to produce, for logging
     * @param maxAttempts - Optional, how many times to check (soft-limited to minimum of 1)
     */
    _checkProducesElement: function (callerName, elementLookup, elementDescription, maxAttempts) {
        // minimum of 1 attempt
        maxAttempts = (maxAttempts === undefined || maxAttempts < 1) ? 1 : maxAttempts;

        // warn user if this is an object that might be destructively or oddly affected by this check
        switch (this.toString()) {
        case "[object UIAButton]":
        case "[object UIALink]":
        case "[object UIAActionSheet]":
        case "[object UIAKey]":
        case "[object UIAKeyboard]":
            UIALogger.logWarning(callerName + " is going to tap() an object of type " + this.toString());
        default:
            // no warning
        }

        var elem;
        try {
            var didFirstTap = false;
            do {
                if (didFirstTap) {
                    UIALogger.logDebug(callerName + ": retrying element tap, because "
                                       + elementDescription + " = " + elem
                                       + " with " + maxAttempts.toString() + " remaining attempts");
                }
                maxAttempts--;

                this.tap();
                didFirstTap = true;
                delay(0.35); // element should take roughly this long to appear (or disappear if was visible for other field).
                //bonus: delays the while loop

                elem = elementLookup();
            } while (!elem.isNotNil() && 0 < maxAttempts);

            if (!elem.isNotNil()) return false;

            elem.waitForVisibility(1, true);
            return true;
        } catch (e) {
            UIALogger.logDebug("_checkProduceElement (for " + callerName + ") caught error: " + e);
            return false;
        }
    },


    /**
     * verify that a text field is editable by tapping in it and waiting for a keyboard to appear.
     */
    checkIsEditable: function (maxAttempts) {
        var getKb = function () {
            return target().frontMostApp().keyboard();
        };
        return this._checkProducesElement("checkIsEditable", getKb, "keyboard", maxAttempts);
    },

    /**
     * verify that a text field is editable by tapping in it and waiting for a keyboard to appear.
     */
    checkIsPickable: function (maxAttempts) {
        var getPicker = function () {
            return target().frontMostApp().windows()[1].pickers()[0];
        };
        return this._checkProducesElement("checkIsPickable", getPicker, "picker", maxAttempts);
    },

});



extendPrototype(UIAApplication, {

    /**
     * Wait for this element to become visible
     *
     * @param timeout the timeout in seconds
     * @param orientation integer the screen orientation constant (e.g. UIA_DEVICE_ORIENTATION_PORTRAIT)
     */
    waitForInterfaceOrientation: function (timeout, orientation) {
        return this._waitForPropertyOfElement(timeout, "waitForInterfaceOrientation", "interfaceOrientation", orientation);
    },

    /**
     * Wait for portrait orientation
     *
     * @param timeout the timeout in seconds
     */
    waitForPortraitOrientation: function (timeout) {
        return this._waitForPropertyOfElement(timeout, "waitForInterfaceOrientation", "interfaceOrientation",
                                              [UIA_DEVICE_ORIENTATION_PORTRAIT, UIA_DEVICE_ORIENTATION_PORTRAIT_UPSIDEDOWN]);
    },

    /**
     * Wait for landscape orientation
     *
     * @param timeout the timeout in seconds
     */
    waitForLandscapeOrientation: function (timeout) {
        return this._waitForPropertyOfElement(timeout, "waitForInterfaceOrientation", "interfaceOrientation",
                                              [UIA_DEVICE_ORIENTATION_LANDSCAPELEFT, UIA_DEVICE_ORIENTATION_LANDSCAPERIGHT]);
    }
});

extendPrototype(UIATarget, {

    /**
     * Wait for this element to become visible
     *
     * @param timeout the timeout in seconds
     * @param orientation integer the screen orientation constant (e.g. UIA_DEVICE_ORIENTATION_PORTRAIT)
     */
    waitForDeviceOrientation: function (timeout, orientation) {
        return this._waitForPropertyOfElement(timeout, "waitForDeviceOrientation", "deviceOrientation", orientation);
    },

    /**
     * Wait for portrait orientation
     *
     * @param timeout the timeout in seconds
     */
    waitForPortraitOrientation: function (timeout) {
        return this._waitForPropertyOfElement(timeout, "waitForDeviceOrientation", "deviceOrientation",
                                              [UIA_DEVICE_ORIENTATION_PORTRAIT, UIA_DEVICE_ORIENTATION_PORTRAIT_UPSIDEDOWN]);
    },

    /**
     * Wait for landscape orientation
     *
     * @param timeout the timeout in seconds
     */
    waitForLandscapeOrientation: function (timeout) {
        return this._waitForPropertyOfElement(timeout, "waitForDeviceOrientation", "deviceOrientation",
                                              [UIA_DEVICE_ORIENTATION_LANDSCAPELEFT, UIA_DEVICE_ORIENTATION_LANDSCAPERIGHT]);
    }

});

extendPrototype(UIATextField, {
    typeString: typeString,
    clear: function () {
        this.typeString("", true);
    },
    pickDate: pickDate,
});

extendPrototype(UIATextView, {
    typeString: typeString,
    clear: function () {
        this.typeString("", true);
    },
    pickDate: pickDate
});

extendPrototype(UIAStaticText, {
    pickDate: pickDate
});


extendPrototype(UIATableView, {
    /**
     * Fix a shortcoming in UIAutomation's ability to scroll to an item by predicate
     * @param cellPredicate string predicate as defined in UIAutomation spec
     */
    getCellWithPredicateByScrolling: function (cellPredicate) {
        var delayToPreventUIAutomationBug = 0.4;
        var lastApparentSize = this.cells().length;
        var lastVisibleCell = -1;
        var thisVisibleCell = -1;

        if (0 == lastApparentSize) return newUIAElementNil();

        // scroll to first cell if we can't see it
        var initializeScroll = function (self) {
            self.cells()[0].scrollToVisible();
            lastVisibleCell = thisVisibleCell = 0;
            delay(delayToPreventUIAutomationBug);
        };

        var downScroll = function (self) {
            UIALogger.logDebug("downScroll");
            self.scrollDown();
            delay(delayToPreventUIAutomationBug);
        };

        // scroll down until we've made all known cells visible at least once
        for (initializeScroll(this); lastVisibleCell < (this.cells().length - 1); downScroll(this)) {
            // find this visible cell
            for (var i = lastVisibleCell; this.cells()[i].isVisible(); ++i) {
                thisVisibleCell = i;
                var ret = this.cells().firstWithPredicate(cellPredicate);
                if (ret && ret.isNotNil()) {
                    ret.scrollToVisible();
                    delay(delayToPreventUIAutomationBug);
                    return ret;
                }
            }
            UIALogger.logDebug("Cells " + lastVisibleCell + " to " + thisVisibleCell + " of " + this.cells().length
                               + " didn't match predicate: " + cellPredicate);

            lastVisibleCell = thisVisibleCell;
        }

        return newUIAElementNil();
    }

});
