// Extensions.js - Extensions to Apple's UIAutomation library


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Exceptions
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Decode a stack trace into something readable
 *
 * UIAutomation has a decent `.backtrace` property for errors, but ONLY for the `Error` class.
 * As of this writing, many attempts to produce that property on user-defined error classes have failed.
 * This function decodes the somewhat-readable `.stack` property into something better
 *
 * Decode the following known types of stack lines:
 *  - built-in functions in this form: funcName@[native code]
 *  - anonymous functions in this form: file://<path>/file.js:line:col
 *  - named functions in this form: funcName@file://<path>/file.js:line:col
 *  - top-level calls in this form: global code@file://<path>/file.js:line:col
 *
 * @param trace string returned by the "stack" property of a caught exception
 * @return object
 *  { isOK:      boolean, whether any errors at all were encountered
 *    message:   string describing any error encountered
 *    errorName: string name of the error
 *    stack:     array of trace objects [
 *               { functionName: string name of function, or undefined if the function was anonymous
 *                 nativeCode:   boolean whether the function was defined in UIAutomation binary code
 *                 file:         if not native code, the basename of the file containing the function
 *                 line:         if not native code, the line where the function is defined
 *                 column:       if not native code, the column where the function is defined
 *               }
 *         ]
 *  }
 *
 */
function decodeStackTrace(err) {
    if ("string" == (typeof err)) {
        return {isOK: false, message: "[caught string error, not an error class]", stack: []};
    }

    if (err.stack === undefined) {
        return {isOK: false, message: "[caught an error without a stack]", stack: []};
    }

    var ret = {isOK: true, stack: []};
    if (err.name !== undefined) {
        ret.errorName = err.name;
        ret.message = "<why are you reading this? there is nothing wrong.>";
    } else {
        ret.errorName = "<unnamed>";
        ret.message = "[Error class was unnamed]";
    }

    var lines = err.stack.split("\n");

    for (var i = 0; i < lines.length; ++i) {
        var l = lines[i];
        var r = {};
        var location;

        // extract @ symbol if it exists, which defines whether function is anonymous
        var atPos = l.indexOf("@");
        if (-1 == atPos) {
            location = l;
        } else {
            r.functionName = l.substring(0, atPos);
            location = l.substring(atPos + 1);
        }

        // check whether the function is built in to UIAutomation
        r.nativeCode = ("[native code]" == location);

        // extract file, line, and column if not native code
        if (!r.nativeCode) {
            var tail = location.substring(location.lastIndexOf("/") + 1);
            var items = tail.split(":");
            r.file = items[0];
            r.line = items[1];
            r.column = items[2];
        }


        //string.substring(string.indexOf("_") + 1)
        ret.stack.push(r);
    }

    return ret;
}


/**
 * Get a stack trace (this function omitted) from any location in code
 *
 * @return just the stack property of decodeStackTrace
 */
function getStackTrace() {
    try {
        throw new Error("base");
    } catch (e) {
        return decodeStackTrace(e).stack.slice(1);
    }
}

/**
 * Get the filename of the current file being executed
 *
 * @return the filename
 */
function __file__() {
    // just ask for the 1st position on stack, after the __file__ call itself
    return getStackTrace()[1].file;
}

/**
 * Get the name of the current function being executed
 *
 * @param offset integer whether to
 * @return the function name
 */
function __function__(offset) {
    offset = offset || 0;
    // just ask for the 1st position on stack, after the __function__ call itself
    return getStackTrace()[1 + offset].functionName;
}

/**
 * Shortcut to defining simple error classes
 *
 * @param className string name for the new error class
 * @return a function that is used to construct new error instances
 */
function makeErrorClass(className) {
    return function (message) {
        this.name = className;
        this.message = message;
        this.toString = function() { return this.name + ": " + this.message; };
    };
}

/**
 * Shortcut to defining error classes that indicate the function/file/line that triggered them
 *
 * These are for cases where the errors are expected to be caught by the global error handler
 *
 * @param fileName string basename of the file where the function is defined (gets stripped out)
 * @param className string name for the new error class
 * @return a function that is used to construct new error instances
 */
function makeErrorClassWithGlobalLocator(fileName, className) {

    var _getCallingFunction = function () {
        var stack = getStackTrace();
        // start from 2nd position on stack, after _getCallingFunction and makeErrorClassWithGlobalLocator
        for (var i = 2; i < stack.length; ++i) {
            var l = stack[i];
            if (!(l.nativeCode || fileName == l.file)) {
                return "In " + l.functionName + " at " + l.file + " line " + l.line + " col " + l.column + ": ";
            }
        }
        return "";
    };

   return function (message) {
        this.name = className;
        this.message = _getCallingFunction() + message;
        this.toString = function() { return this.name + ": " + this.message; };
    };
}

IlluminatorSetupException = makeErrorClass("IlluminatorSetupException");
IlluminatorRuntimeFailureException = makeErrorClass("IlluminatorRuntimeFailureException");
IlluminatorRuntimeVerificationException = makeErrorClass("IlluminatorRuntimeVerificationException");


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// General-purpose functions
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * shortcut function to get UIATarget.localTarget(), sets _accessor
 */
function target() {
    var ret = UIATarget.localTarget();
    ret._accessor = "target()";
    return ret;
}

/**
 * shortcut function to get UIATarget.localTarget().frontMostApp().mainWindow(), sets _accessor
 */
function mainWindow() {
    var ret = UIATarget.localTarget().frontMostApp().mainWindow();
    ret._accessor = "mainWindow()";
    return ret;
}

/**
 * shortcut function to get UIATarget.host()
 */
function host() {
    return UIATarget.localTarget().host();
}

/**
 * delay for a number of seconds
 *
 * @param seconds float how long to wait
 */
function delay(seconds) {
    target().delay(seconds);
}

/**
 * get the current time: seconds since epoch, with decimal for millis
 */
function getTime() {
    return (new Date).getTime() / 1000;
}


/**
 * EXTENSION PROFILER
 */
(function() {

    var root = this,
        extensionProfiler = null;

    // put extensionProfiler in namespace of importing code
    if (typeof exports !== 'undefined') {
        extensionProfiler = exports;
    } else {
        extensionProfiler = root.extensionProfiler = {};
    }

    /**
     * reset the stored criteria costs
     */
    extensionProfiler.resetCriteriaCost = function () {
        extensionProfiler._criteriaCost = {};
        extensionProfiler._criteriaTotalCost = {}
        extensionProfiler._criteriaTotalHits = {};
        extensionProfiler._bufferCriteria = false;
    };
    extensionProfiler.resetCriteriaCost(); // initialize it


    /**
     * sometimes critera are evaluated in a loop because we are waiting for something; don't count that
     *
     * indicates that we should store ONLY THE MOST RECENT lookup times in an array
     */
    extensionProfiler.bufferCriteriaCost = function() {
        extensionProfiler._bufferCriteria = true;
    };


    /**
     * sometimes critera are evaluated in a loop because we are waiting for something; don't count that
     *
     * indicates that we should store ONLY THE MOST RECENT lookup times in an array
     */
    extensionProfiler.UnbufferCriteriaCost = function() {
        extensionProfiler._bufferCriteria = false;
        // replay the most recent values into the totals
        for (var c in extensionProfiler._criteriaCost) {
            extensionProfiler.recordCriteriaCost(c, extensionProfiler._criteriaCost[c]);
        }
        extensionProfiler._criteriaCost = {};
    };


    /**
     * keep track of the cumulative time spent looking for criteria
     *
     * @param criteria the criteria object or object array
     * @param time the time spent looking up that criteria
     */
    extensionProfiler.recordCriteriaCost = function (criteria, time) {
        // criteria can be a string if it comes from our buffered array, so allow it.
        var key = (typeof criteria) == "string" ? criteria : JSON.stringify(criteria);
        if (extensionProfiler._bufferCriteria) {
            extensionProfiler._criteriaCost[key] = time; // only store the most recent one, we'll merge later
        } else {
            if (undefined === extensionProfiler._criteriaTotalCost[key]) {
                extensionProfiler._criteriaTotalCost[key] = 0;
                extensionProfiler._criteriaTotalHits[key] = 0;
            }
            extensionProfiler._criteriaTotalCost[key] += time;
            extensionProfiler._criteriaTotalHits[key]++;
        }
    };

    /**
     * return an array of objects indicating the cumulative time spent looking for criteria -- high time to low
     *
     * @return array of {criteria: x, time: y, hits: z} objects
     */
    extensionProfiler.getCriteriaCost = function () {
        var ret = [];
        for (var criteria in extensionProfiler._criteriaTotalCost) {
            ret.push({"criteria": criteria,
                      "time": extensionProfiler._criteriaTotalCost[criteria],
                      "hits": extensionProfiler._criteriaTotalHits[criteria]});
        }
        ret.sort(function(a, b) { return b.time - a.time; });
        return ret;
    };

}).call(this);


/**
 * convert a number of seconds to hh:mm:ss.ss
 *
 * @param seconds the number of seconds (decimal OK)
 */
function secondsToHMS(seconds) {
    var s = Math.floor(seconds);
    var f = seconds - s;
    var h = Math.floor(s / 3600);
    s -= h * 3600;
    var m = Math.floor(s / 60);
    s -= m * 60;

    // build strings
    h = h > 0 ? (h + ":") : "";
    m = (m > 9 ? m.toString() : ("0" + m.toString())) + ":";
    s = s > 9 ? s.toString() : ("0" + s.toString());
    f = f > 0 ? ("." + Math.round(f * 100).toString()) : "";
    return h + m + s + f;
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
    try {
        UIATarget.localTarget().pushTimeout(0);
        return UIATarget.localTarget().frontMostApp().windows().firstWithPredicate("name == 'Illuminator' and name == 'newUIAELementNil()'");
    } catch(e) {
        throw e;
    } finally {
        UIATarget.localTarget().popTimeout();
    }
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
function waitForReturnValue(timeout, callerName, functionReturningValue) {
    var myGetTime = function () {
        return (new Date).getTime() / 1000;
    }

    switch (typeof timeout) {
    case "number": break;
    default: throw new IlluminatorSetupException("waitForReturnValue got a bad timeout type: (" + (typeof timeout) + ") " + timeout);
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

    throw new IlluminatorRuntimeFailureException(callerName + " failed by timeout after " + timeout + " seconds: " + caught);
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
        throw new IlluminatorRuntimeFailureException(msg);
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

    // search in the appropriate way
    if (!(criteria instanceof Array)) {
        criteria = [criteria];
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

    var startTime = getTime();
    try {
        return segmentedFind(criteria, parentElem, elemAccessor);
    } catch (e) {
        throw e;
    } finally {
        var cost = getTime() - startTime;
        extensionProfiler.recordCriteriaCost(criteria, cost);
    }
}

/**
 * Resolve a string expression to a UIAElement using Eval
 *
 * @param selector string
 * @param element the element to use as a starting point
 */
function getChildElementFromEval(selector, element) {
    // wrapper function for lookups, only return element if element is visible
    var visible = function (elem) {
        return elem.isVisible() ? elem : newUIAElementNil();
    }

    try {
        return eval(selector);
    } catch (e) {
        if (e instanceof SyntaxError) {
            throw new IlluminatorSetupException("Couldn't evaluate string selector '" + selector + "': " + e);
        } else if (e instanceof TypeError) {
            throw new IlluminatorSetupException("Evaluating string selector on element " + element + " triggered " + e);
        } else {
            throw e;
        }
    }
}

/**
 * construct an input method
 */
function newInputMethod(methodName, description, isActiveFn, selector, features) {
    var ret = {
        name: methodName,
        description: description,
        isActiveFn: isActiveFn,
        selector: selector,
        features: {}
    };

    for (var k in features) {
        ret.features[k] = features[k];
    }

    return ret;
}

var stockKeyboardInputMethod = newInputMethod("defaultKeyboard",
                                              "Any default iOS keyboard, whether numeric or alphanumeric",
                                              function () {
                                                  return isNotNilElement(target().frontMostApp().keyboard());
                                              },
                                              function (targ) {
                                                  return targ.frontMostApp().keyboard();
                                              },
                                              {});


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Object prototype functions
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * set the (custom) input method for an element
 *
 * @param method the input method
 */
function setInputMethod(method) {
    this._inputMethod = method;
}

/**
 * Access the custom input method for an element
 */
function customInputMethod() {
    if (this._inputMethod === undefined) throw new IlluminatorSetupException("No custom input method defined for element " + this);
    var inpMth = this._inputMethod;

    // open custom input method
    this.checkIsEditable(2);

    // assign any feature functions to it
    var theInput = target().getOneChildElement(inpMth.selector);
    for (var f in inpMth.features) {
        theInput[f] = inpMth.features[f];
    }
    return theInput;
}

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
        throw new IlluminatorRuntimeFailureException("typeString couldn't get the keyboard to appear for element "
                                                     + this.toString() + " with name '" + this.name() + "'");
    }

    var kb; // keyboard
    var seconds = 2;
    var waitTime = 0.25;
    var maxAttempts = seconds / waitTime;
    var noSuccess = true;
    var failMsg = null;


    // get whichever keyboard was specified by the user
    kb = target().getOneChildElement(this._inputMethod.selector);

    // if keyboard doesn't have a typeString (indicating a custom keyboard) then attempt to load that feature
    if (kb.typeString === undefined) {
        kb.typeString = this._inputMethod.features.typeString;
        if (kb.typeString === undefined) {
            throw new IlluminatorSetupException("Attempted to use typeString() on a custom keyboard that did not define a 'typeString' feature");
        }
    }

    if (kb.clear === undefined) {
        kb.clear = this._inputMethod.features.clear;
        if (clear && kb.clear === undefined) {
            throw new IlluminatorSetupException("Attempted to use clear() on a custom keyboard that did not define a 'clear' feature");
        }
    }

    // attempt to get a successful keypress several times -- using the first character
    // this is a hack for iOS 6.x where the keyboard is sometimes "visible" before usable
    while ((clear || noSuccess) && 0 < maxAttempts--) {
        try {

            // handle clearing
            if (clear) {
                kb.clear(this);
                clear = false; // prevent clear on next iteration
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
    if (0 > maxAttempts && null !== failMsg) throw new IlluminatorRuntimeFailureException("typeString caught error: " + failMsg);

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

}

/**
 * Type a string into a keyboard-like element
 *
 * Element "this" should have UIAKey elements, and this function will attempt to render the string with the available keys
 *
 * @todo get really fancy and solve key sequences for keys that have multiple characters on them
 * @param text the text to type
 */
function typeStringCustomKeyboard(text) {
    var keySet = this.keys();
    for (var i = 0; i < text.length; ++i) {
        var keyElem = keySet.firstWithName(text[i]);
        if (!isNotNilElement(keyElem)) throw new IlluminatorRuntimeFailureException("typeStringCustomKeyboard failed to find key for " + text[i]);
        keyElem.tap();
    }
}

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



extendPrototype(UIASwitch, {
    /**
     *  replacement for setValue on UIASwitch that retries setting value given number of times
     *
     * @param value boolean value to set on switch
     * @param retries integer number of retries to do, defaults to 3
     * @param delaySeconds integer delay between retries in seconds, defaults to 1
     */
    safeSetValue: function (value, retries, delaySeconds) {
        retries = retries || 3;
        delaySeconds = delaySeconds || 1;
        var exception = null;
        for (i = 0; i <= retries; ++i) {
            try {
                this.setValue(value);
                return;
            } catch (e) {
                exception = e
                delay(delaySeconds);
                UIALogger.logWarning("Set switch value failed " + i + " times with error " + e);
            }
        }
        if (exception !== null) {
            throw exception;
        }
    },
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
        if (isHardSelector(criteria)) throw new IlluminatorSetupException("getChildElements got a hard selector, which cannot return multiple elements");
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
            return getChildElementFromEval(selector, this)
        default:
            throw new IlluminatorSetupException(caller + " received undefined input type of " + (typeof selector).toString());
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
        var sameRect = function (e1, e2) {
            var r1 = e1.rect();
            var r2 = e2.rect();
            return r1.size.width  == r2.size.width
                && r1.size.height == r2.size.height
                && r1.origin.x    == r2.origin.x
                && r1.origin.y    == r2.origin.y;
        }

        maxRecursion = maxRecursion === undefined ? -1 : maxRecursion;

        if (this == elem2) return true; // shortcut when x == x
        if (null === elem2) return false; // shortcut when one is null
        if (isNotNilElement(this) != isNotNilElement(elem2)) return false; // both nil or neither
        if (this.toString() != elem2.toString()) return false; // element type
        if (this.name() != elem2.name()) return false;
        if (!sameRect(this, elem2)) return false; // possible false positives!
        if (this.isVisible() != elem2.isVisible()) return false; // hopefully a way to beat false positives
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
        var t0 = getTime();
        var currentTimeout = preferences.extensions.reduceTimeout;
        var stopTime = t0 + currentTimeout;

        var checkTimeout = function (currentOperation) {
            if (stopTime < getTime()) {
                UIALogger.logDebug("_reduce: " + currentOperation + " hit preferences.extensions.reduceTimeout limit"
                                   + " of " + currentTimeout + " seconds; terminating with possibly incomplete result");
                return true;
            }
            return false;
        };

        var reduce_helper = function (elem, acc, prefix) {
            var scalars = ["frontMostApp", "mainWindow", "keyboard", "popover"];
            var vectors = [];

            // iOS 8.1 takes between 3 and 5 milliseconds each (????!?!?!) to evaluate these, so only do it for 7.x
            if (isSimVersion(7)) {
                vectors = ["activityIndicators", "buttons", "cells", "collectionViews", "images","keys",
                           "links", "navigationBars", "pageIndicators", "pickers", "progressIndicators",
                           "scrollViews", "searchBars", "secureTextFields", "segmentedControls", "sliders",
                           "staticTexts", "switches", "tabBars", "tableViews", "textFields", "textViews",
                           "toolbars", "webViews", "windows"];
            }

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
                visit(elem[scalars[i]](), prefix + "." + scalars[i] + "()", false);
            }

            // visit the elements of the vectors
            for (var i = 0; i < vectors.length; ++i) {
                if (undefined === elem[vectors[i]]) continue;
                var elemArray = elem[vectors[i]]();
                if (undefined === elemArray) continue;
                for (var j = 0; j < elemArray.length; ++j) {
                    var newElem = elemArray[j];
                    if (vectors[i] == "windows" && j == 0) continue;
                    visit(newElem, prefix + "." + vectors[i] + "()[" + getNamedIndex(elemArray, j) + "]", false);

                    if (checkTimeout("vector loop")) return acc; // respect timeout preference
                }
            }

            // visit any un-visited items
            var elemArray = elem.elements();
            for (var i = 0; i < elemArray.length; ++i) {
                visit(elemArray[i], prefix + ".elements()[" + getNamedIndex(elemArray, i) + "]", true);

                if (checkTimeout("element loop")) return acc; // respect timeout preference
            }
            return acc;
        };

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
     *  * rect, hasKeyboardFocus, isEnabled, isValid, isVisible, label, name, value:
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
            if (c.UIAType          !== undefined && "[object " + c.UIAType + "]" != elem.toString()) return acc;
            if (c.rect             !== undefined && JSON.stringify(c.rect) != JSON.stringify(elem.rect())) return acc;
            if (c.hasKeyboardFocus !== undefined && c.hasKeyboardFocus != elem.hasKeyboardFocus()) return acc;
            if (c.isEnabled        !== undefined && c.isEnabled != elem.isEnabled()) return acc;
            if (c.isValid          !== undefined && c.isValid !== elem.isValid()) return acc;
            if (c.label            !== undefined && c.label != elem.label()) return acc;
            if (c.name             !== undefined && c.name != elem.name()) return acc;
            if (c.nameRegex        !== undefined && (elem.name() === null || elem.name().match(c.nameRegex) === null)) return acc;
            if (c.value            !== undefined && c.value != elem.value()) return acc;

            acc[varName + prefix] = elem;
            elem._accessor = varName + prefix; // annotate the element with its accessor
            return acc;
        }

        return this._reduce(collect_fn, {}, visibleOnly);
    },

    /**
     * Take a screen shot of this element
     *
     * @param imageName A string to use as the name for the resultant image file
     */
    captureImage: function (imageName) {
        target().captureRectWithName(this.rect(), imageName);
    },

    /**
     * Capture images for this element and all its child elements
     *
     * @param imageName A string to use as the base name for the resultant image files
     */
    captureImageTree: function (imageName) {
        var captureFn = function (acc, element, prefix, _) {
            element.captureImage(imageName + " element" + prefix);
            return acc;
        };

        this._reduce(captureFn, undefined, true);
    },

    /**
     * Get a list of valid element references in .js format for copy/paste use in code
     * @param varname is used as the first element in the canonical name
     * @param visibleOnly boolean whether to only get visible elements
     * @return array of strings
     */
    getChildElementReferences: function (varName, visibleOnly) {
        varName = varName === undefined ? "<root element>" : varName;

        var collectFn = function (acc, _, prefix, __) {
            acc.push(varName + prefix)
            return acc;
        };

        return this._reduce(collectFn, [], visibleOnly);
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
                if (undefined === obj[propertyName]) throw new IlluminatorSetupException("Couldn't get property '" + propertyName + "' of object " + obj);
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
            var msg = ["Value of property '", propertyName, "'",
                       " on ", thisObj, " \"", thisObj.name(), "\"",
                       " is (" + (typeof actual) + ") '" + actual + "'"].join("");
            if (desiredValue instanceof Array) {
                msg += ", not one of the desired values ('" + desiredValues.join("', '") + "')";
            } else {
                msg += ", not the desired value (" + (typeof desiredValue) + ") '" + desiredValue + "'";
            }
            throw new IlluminatorRuntimeVerificationException(msg);
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
            throw new IlluminatorRuntimeFailureException("No acceptable value for " + returnName + " on "
                                                         + thisObj + " \"" + thisObj.name()
                                                         + "\" was returned from " + inputDescription);
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
        if (undefined === selector) throw new IlluminatorSetupException("waitForChildExistence: No selector was specified");

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
                    throw new IlluminatorSetupException("Selector (criteria) returned " + Object.keys(result).length + " results, not 0: "
                                                        + JSON.stringify(result));
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
            extensionProfiler.bufferCriteriaCost();
            return this._waitForReturnFromElement(timeout, "waitForChildExistence", inputDescription, description, isDesired, actualValFn);
        } catch (e) {
            throw e;
        } finally {
            UIATarget.localTarget().popTimeout();
            extensionProfiler.UnbufferCriteriaCost();
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
        if ((typeof selectors) != "object") throw new IlluminatorSetupException("waitForChildSelect expected selectors to be an object, "
                                                                                + "but got: " + (typeof selectors));

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
            extensionProfiler.bufferCriteriaCost();
            return this._waitForReturnFromElement(timeout, "waitForChildSelect", inputDescription, description, foundAtLeastOne, findAll);
        } catch (e) {
            throw e;
        } finally {
            UIATarget.localTarget().popTimeout();
            extensionProfiler.UnbufferCriteriaCost();
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
        if (this.isVisible()) {
            try {
                this.scrollToVisible();
            } catch (e) {
                // iOS 6 hack when no scrolling is needed
                if (e.toString() != "scrollToVisible cannot be used on the element because it does not have a scrollable ancestor.") {
                    throw e;
                }
            }
        }
        this.vtap(timeout);
    },

    /**
     * Check whether tapping this element produces its input method
     *
     * (this) - the element that we will tap
     * @param maxAttempts - Optional, how many times to check (soft-limited to minimum of 1)
     */
    checkIsEditable: function (maxAttempts) {
        // minimum of 1 attempt
        maxAttempts = (maxAttempts === undefined || maxAttempts < 1) ? 1 : maxAttempts;

        if (this._inputMethod === undefined) return false;
        var inpMth = this._inputMethod;

        // warn user if this is an object that might be destructively or oddly affected by this check
        switch (this.toString()) {
        case "[object UIAButton]":
        case "[object UIALink]":
        case "[object UIAActionSheet]":
        case "[object UIAKey]":
        case "[object UIAKeyboard]":
            UIALogger.logWarning("checkIsEditable is going to tap() an object of type " + this.toString());
        default:
            // no warning
        }

        var elem;
        try {
            var didFirstTap = false;
            do {
                if (didFirstTap) {
                    UIALogger.logDebug("checkIsEditable: retrying element tap, because "
                                       + inpMth.name + " = " + elem
                                       + " with " + maxAttempts.toString() + " remaining attempts");
                }
                maxAttempts--;

                this.tap();
                didFirstTap = true;
                delay(0.35); // element should take roughly this long to appear (or disappear if was visible for other field).
                //bonus: delays the while loop

                elem = target().getChildElement(inpMth.selector);
            } while (!elem.isNotNil() && 0 < maxAttempts);

            if (!elem.isNotNil()) return false;

            elem.waitForVisibility(1, true);
            return true;
        } catch (e) {
            UIALogger.logDebug("checkIsEditable caught error: " + e);
            return false;
        }
    },

    /**
     * Treat this element as if it is an editable field
     *
     * This function is a workaround for some cases where an editable element (such as a text field) inside another element
     * (such as a table cell) fails to bring up the keyboard when tapped.  The workaround is to tap the table cell instead.
     * This function adds editability support to elements that ordinarily would not have it.
     */
    useAsEditableField: function () {
        this._inputMethod = stockKeyboardInputMethod;
        this.setInputMethod = setInputMethod;
        this.customInputMethod = customInputMethod;
        this.typeString = typeString;
        return this;
    }

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


extendPrototype(UIAHost, {

    /**
     * Execute a shell command as if it was a function
     *
     * If the command doesn't return succss, raise an error with the from the shell as if it was from a Javascript function
     *
     * @param command the command to run
     * @param args an array of arguments
     * @param timeout the timeout for the command
     */
    shellAsFunction: function (command, args, timeout) {
        var result = this.performTaskWithPathArgumentsTimeout(command, args, timeout);

        // be verbose if something didn't go well
        if (0 != result.exitCode) {
            var owner = __function__(1); // not this function, but the calling function
            throw new Error(owner + " failed: " + result.stderr);
        }
        return result.stdout;
    },

    /**
     * Attempt to parse JSON, raise helpful error if it fails, containing the calling function name
     *
     * @param maybeJSON string that should contain JSON
     * @return object
     */
    _guardedJSONParse: function (maybeJSON) {
        try {
            return JSON.parse(maybeJSON);
        } catch(e) {
            var owner = __function__(1);
            throw new Error(owner + " gave bad JSON: ```" + maybeJSON + "```");
        }
    },

    /**
     * Read data from a file
     *
     * @param path the path that should be read
     * @return string the file contents
     */
    readFromFile: function (path) {
        return this.shellAsFunction("/bin/cat", [path], 10);
    },

    /**
     * Read JSON data from a file
     *
     * @param path the path that should be read
     * @return object
     */
    readJSONFromFile: function (path) {
        return this._guardedJSONParse(this.readFromFile(path));
    },

    /**
     * Read JSON data from a plist file
     *
     * @param path the path that should be read
     * @return object
     */
    readJSONFromPlistFile: function (path) {
        var scriptPath = IlluminatorScriptsDirectory + "/plist_to_json.sh";
        UIALogger.logDebug("Running " + scriptPath + " '" + path + "'");

        return this._guardedJSONParse(this.shellAsFunction(scriptPath, [path], 10));
    },


    /**
     * Write data to a file
     *
     * @param path the path that should be (over)written
     * @data the data of the file to write in string format
     */
    writeToFile: function (path, data) {
        // type check
        switch (typeof data) {
        case "string": break;
        default: throw new TypeError("writeToFile expected data in string form, got type " + (typeof data));
        }

        var chunkSize = Math.floor(262144 * 0.74) - (path.length + 100); // `getconf ARG_MAX`, adjusted for b64

        var writeHelper = function (b64stuff, outputPath) {
            var result = target().host().performTaskWithPathArgumentsTimeout("/bin/sh", ["-c",
                                                                                         "echo \"$0\" | base64 -D -o \"$1\"",
                                                                                         b64stuff,
                                                                                         outputPath], 5);

            // be verbose if something didn't go well
            if (0 != result.exitCode) {
                UIALogger.logDebug("Exit code was nonzero: " + result.exitCode);
                UIALogger.logDebug("SDOUT: " + result.stdout);
                UIALogger.logDebug("STDERR: " + result.stderr);
                UIALogger.logDebug("I tried this command: ");
                UIALogger.logDebug("/bin/sh -c \"echo \\\"\\$0\\\" | base64 -D -o \\\"\\$1\\\" " + b64stuff + " " + outputPath);
                return false;
            }
            return true;
        }

        var result = true;
        if (data.length < chunkSize) {
            var b64data = Base64.encode(data);
            UIALogger.logDebug("Writing " + data.length + " bytes to " + path + " as " + b64data.length + " bytes of b64");
            result = result && writeHelper(b64data, path);

        } else {
            // split into chunks to avoid making the command line too long
            splitRegex = function(str, len) {
                var regex = new RegExp('[\\s\\S]{1,' + len + '}', 'g');
                return str.match(regex);
            }

            // write each chunk to a file
            var chunks = splitRegex(data, chunkSize);
            var chunkFiles = [];
            for (var i = 0; i < chunks.length; ++i) {
                var chunk = chunks[i];
                var chunkFile = path + ".chunk" + i;
                var b64data = Base64.encode(chunk);
                UIALogger.logDebug("Writing " + chunk.length + " bytes to " + chunkFile + " as " + b64data.length + " bytes of b64");
                result = result && writeHelper(b64data, chunkFile);
                chunkFiles.push(chunkFile);
            }

            // concatenate all the chunks
            var unchunkCmd = "cat \"" + chunkFiles.join("\" \"") + "\" > \"$0\"";
            UIALogger.logDebug("Concatenating and deleting " + chunkFiles.length + " chunks, writing " + path);
            target().host().performTaskWithPathArgumentsTimeout("/bin/sh", ["-c", unchunkCmd, path], 5);
            target().host().performTaskWithPathArgumentsTimeout("/bin/rm", chunkFiles, 5);
        }

        return result;
    }

});


extendPrototype(UIATarget, {

    /**
     * Add a photo to the iPhoto library
     *
     * @param path the photo path
     */
    addPhoto: function (path) {
        host().shellAsFunction(config.xcodePath + "/usr/bin/simctl", ["addphoto", config.targetDeviceID, path], 15);
    },

    /**
     * Connect or disconnect the hardware keyboard
     *
     * @param connected boolean whether the keyboard is connected
     */
    connectHardwareKeyboard: function (connected) {
        if (config.isHardware) {
            throw new IlluminatorSetupException("Can't set the hardware keyboard option for a non-simulated device");
        }
        var on = connected ? "1" : "0";
        var scriptPath = IlluminatorScriptsDirectory + "/set_hardware_keyboard.applescript";

        host().shellAsFunction("/usr/bin/osascript", [scriptPath, on], 5);
    },

    /**
     * Open a URL on the target device
     *
     * @param url string the URL
     */
    openURL: function (url) {
        host().shellAsFunction(config.xcodePath + "/usr/bin/simctl", ["openurl", config.targetDeviceID, url], 5);
    },

    /**
     * Trigger icloud sync
     *
     */
    iCloudSync: function () {
        host().shellAsFunction(config.xcodePath + "/usr/bin/simctl", ["icloud_sync", config.targetDeviceID], 5);
    },

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

extendPrototype(UIAKeyboard, {
    clear: function (inputField) {

        var kb = this; // keyboard
        var db; // deleteButton
        var blindDelete = false;
        var preDeleteVal = "";
        var postDeleteVal = "";

        // find many types of keyboard delete buttons, then just use the first one we get
        var getDeletionElement = function () {
            delButtons = kb.waitForChildSelect(5, {
                // TODO: handle other languages, possibly by programmatically generating this
                "key": function (keyboard) { return keyboard.keys()["Delete"]; },
                "button": function (keyboard) { return keyboard.buttons()["Delete"]; },
                "element": function (keyboard) { return keyboard.elements()["Delete"]; },
            });
            for (var k in delButtons) {
                return delButtons[k]; // first one is fine
            }

            return newUIAElementNil();
        }

        // wrapper for tapping the delete button.
        var tapDeleteButton = function (duration) {
            // initial condition
            if (db === undefined) {
                db = getDeletionElement();
            }

            // tap the proper way given whether we want to tap for a duration
            if (duration) {
                db.tapWithOptions({duration: duration})
            } else {
                var t0 = getTime();
                db.tap();
                // this hack keeps deletion snappy when it crosses a word boundary (after which tapping can take 2 seconds)
                if (0.3 < getTime() - t0) {
                    db = getDeletionElement();
                }
            }
        }

        // calling "this.value()" on an element is a necessary hack to make long-press deletion work on iPad.  Seriously.
        if (inputField.value) {
            preDeleteVal = inputField.value();
        }

        // another necessary hack: without it, tapWithOptions / touchAndHold for blind delete doesn't work
        tapDeleteButton();

        // find out if we affected the input field
        if (inputField.value) {
            postDeleteVal = inputField.value();
        }

        // don't delete blindly if initial val was non-empty and deleting changed the value in the way we expected
        blindDelete = !(0 < preDeleteVal.length && (1 == preDeleteVal.length - postDeleteVal.length));

        if (blindDelete) {
            tapDeleteButton(3.7);
        } else {
            for (var i = 0; i < postDeleteVal.length; ++i) {
                tapDeleteButton();
            }
        }

    }
});


extendPrototype(UIATextField, {
    typeString: typeString,
    clear: function () {
        this.typeString("", true);
    },
    _inputMethod: stockKeyboardInputMethod,
    setInputMethod: setInputMethod,
    customInputMethod: customInputMethod
});

extendPrototype(UIASecureTextField, {
    typeString: typeString,
    clear: function () {
        this.typeString("", true);
    },
    _inputMethod: stockKeyboardInputMethod,
    setInputMethod: setInputMethod,
    customInputMethod: customInputMethod
});


extendPrototype(UIATextView, {
    typeString: typeString,
    clear: function () {
        this.typeString("", true);
    },
    _inputMethod: stockKeyboardInputMethod,
    setInputMethod: setInputMethod,
    customInputMethod: customInputMethod
});

extendPrototype(UIAStaticText, {
    _inputMethod: stockKeyboardInputMethod,
    setInputMethod: setInputMethod,
    customInputMethod: customInputMethod
});


extendPrototype(UIATableView, {
    /**
     * Fix a shortcoming in UIAutomation's ability to scroll to an item - general purpose edition
     *
     * @param thingDescription what we are looking for, used in messaging
     * @param getSomethingFn a function that takes the table as its only argument and returns the element we want (or UIAElementNil)
     * @return an element
     */
    _getSomethingByScrolling: function (thingDescription, getSomethingFn) {
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
        var unproductiveScrolls = 0;
        for (initializeScroll(this); lastVisibleCell < (this.cells().length - 1); downScroll(this)) {
            // find this visible cell
            for (var i = lastVisibleCell; this.cells()[i].isVisible(); ++i) {
                thisVisibleCell = i;
            }
            var ret = getSomethingFn(this);
            if (isNotNilElement(ret)) {
                ret.scrollToVisible();
                delay(delayToPreventUIAutomationBug);
                return ret;
            }

            UIALogger.logDebug("Cells " + lastVisibleCell + " to " + thisVisibleCell + " of " + this.cells().length
                               + " didn't match " + thingDescription);

            // check whether scrolling as productive
            if (lastVisibleCell < thisVisibleCell) {
                unproductiveScrolls = 0;
            } else {
                unproductiveScrolls++;
            }

            if (5 < unproductiveScrolls) {
                UIALogger.logDebug("Scrolling does not appear to be revealing more cells, aborting.");
                return getSomethingFn(this);
            }

            lastVisibleCell = thisVisibleCell;
        }

        return newUIAElementNil();
    },

    /**
     * Fix a shortcoming in UIAutomation's ability to scroll to an item by predicate
     * @param cellPredicate string predicate as defined in UIAutomation spec
     * @return an element
     */
    getCellWithPredicateByScrolling: function (cellPredicate) {
        try {
            UIATarget.localTarget().pushTimeout(0);
            return this._getSomethingByScrolling("predicate: " + cellPredicate, function (thisTable) {
                return thisTable.cells().firstWithPredicate(cellPredicate);
            });
        } catch (e) {
            UIALogger.logDebug("getCellWithPredicateByScrolling caught/ignoring: " + e);
        } finally {
            UIATarget.localTarget().popTimeout();
        }

        return newUIAElementNil();
    },

    /**
     * Fix a shortcoming in UIAutomation's ability to scroll to an item by reference
     * @param elementDescription string description of what we are looking for
     * @param selector a selector relative to the table that will return the desired element
     * @return an element
     */
    getChildElementByScrolling: function (elementDescription, selector) {
        try {
            return this._getSomethingByScrolling("selector for " + elementDescription, function (thisTable) {
                return thisTable.getChildElement(selector);
            });
        } catch (e) {
            UIALogger.logDebug("getChildElementByScrolling caught/ignoring: " + e);
        }

        return newUIAElementNil();
    }


});
