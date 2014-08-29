// AppMap.js
//
// creates 'appmap' which can build and store app definitions
// apps have screens
// screens have actions
// actions have parameters
// actions have device-specific implementations

var debugAppmap = false;

(function() {

    var root = this,
        appmap = null;

    // put appmap in namespace of importing code
    if (typeof exports !== 'undefined') {
        appmap = exports;
    } else {
        appmap = root.appmap = {};
    }

    // Exception classes
    appmap.SetupException = makeErrorClassWithGlobalLocator("AppMap.js", "AppMapSetupException");
    appmap.ParameterException = makeErrorClass("AppMapParameterException");

    // internal variables
    appmap.apps = {};       // all possible apps, keyed by string
    var lastApp;            // state variable for building app
    var lastAppName;        // name of last app
    var lastScreen;         // state variable for building screen
    var lastScreenName;     // name of last screen
    var lastAction;         // state variable for building action
    var lastActionName;     // name of last action
    var lastScreenActiveFn; // action function map of last screen

    /**
     * Create a new app in the appmap with the given name.
     *
     * All following screen defintions will be associated with this app.
     *
     * @param appName the desired app name
     * @return this
     */
    appmap.createApp = function(appName) {
        appmap.lastApp = {}; // screens is empty
        appmap.lastAppName = appName;
        appmap.apps[appName] = appmap.lastApp;
        appmap.lastScreen = null;
        appmap.lastAction = null;
        return this;
    };

    /**
     * whether an app exists
     *
     * @param appName the app name to test
     * @return bool
     */
    appmap.hasApp = function(appName) {
        return appName in appmap.apps;
    };

    /**
     * All following screen defintions will be associated with this app.
     *
     * @param appName the desired app name
     * @return this
     */
    appmap.augmentApp = function(appName) {
        appmap.lastApp = appmap.apps[appName];
        appmap.lastAppName = appName;
        return this;
    };

    /**
     * Create a new app if it does not already exist.
     *
     * All following screen definitions will be associated with this app.
     *
     * @param appName the desired app name
     * @return this
     */
    appmap.createOrAugmentApp = function(appName) {
        return appmap.hasApp(appName) ? appmap.augmentApp(appName) : appmap.createApp(appName);
    }


    /**
     * Create a new screen in the appmap with the given name.
     *
     * All following device/action defintions will be associated with this screen.
     *
     * @param screenName the desired screen name
     * @return this
     */
    appmap.withNewScreen = function(screenName) {
        appmap.lastScreen = {};
        appmap.lastScreenName = screenName;
        appmap.lastScreenActiveFn = {};
        appmap.lastAction = null;

        appmap.lastApp[appmap.lastScreenName] = appmap.lastScreen;
        if (debugAppmap) UIALogger.logDebug(" adding screen " + appmap.lastScreenName);

        return this;
    };

    /**
     * whether a screen exists
     *
     * @param appName the app to look in
     * @param screenName the screen name to test
     * @return bool
     */
    appmap.hasScreen = function(appName, screenName) {
        return appmap.hasApp(appName) && (screenName in appmap.apps[appName]);
    }

    /**
     * All following target / action defintions will be associated with this screen
     *
     * @param appName the desired app name
     * @return this
     */
    appmap.augmentScreen = function(screenName) {
        appmap.lastScreenName = screenName;

        appmap.lastScreen = appmap.lastApp[appmap.lastScreenName];
        if (debugAppmap) UIALogger.logDebug(" augmenting screen " + appmap.lastScreenName);
        return this;
    }

    /**
     * Create a new screen if it does not already exist.
     *
     * All following target / action definitions will be associated with this screen.
     *
     * @param screenName the desired screen name
     * @return this
     */
    appmap.withScreen = function(screenName) {
        return appmap.hasScreen(appmap.lastAppName, screenName) ? appmap.augmentScreen(screenName) : appmap.withNewScreen(screenName);
    }

    /**
     * Enable the screen on a given target device
     *
     * @param targetName the name of the target device (e.g. "iPhone", "iPad")
     * @param isActiveFn function that should return true when the screen is currently both visible and accessible
     * @return this
     */
    appmap.onTarget = function(targetName, isActiveFn) {
        var lastScreenName = appmap.lastScreenName;
        if (debugAppmap) UIALogger.logDebug("  on Target " + targetName);
        appmap.lastScreenActiveFn[targetName] = isActiveFn;

        appmap.withAction("verifyIsActive", "Null op to verify that the " + appmap.lastScreenName + " screen is active");
        // slightly hacky, withImplementation expects actions to come AFTER all the onTarget calls
        appmap.lastAction.isCorrectScreen[targetName] = isActiveFn;
        appmap.withImplementation(function() {}, targetName);

        appmap.withAction("verifyNotActive", "Verify that the " + appmap.lastScreenName + " screen is NOT active")
        // slightly hacky, withImplementation expects actions to come AFTER all the onTarget calls
        appmap.lastAction.isCorrectScreen[targetName] = isActiveFn;
        appmap.withImplementation(function() {
                      if (isActiveFn()) {
                          throw new IlluminatorRuntimeVerificationException("Failed assertion that '" + lastScreenName + "' is NOT active ");
                      }
                  }, targetName);

        // now modify verifyNotActive's isCorrectScreen array to always return true.  slighly hacky.
        // this is because the meat of the function runs in our generated action
        for (var d in appmap.lastAction.isCorrectScreen) {
            appmap.lastAction.isCorrectScreen[d] = function (parm) {
                delay((parm === undefined || parm.delay === undefined) ? 0.35 : parm.delay); // wait for animations to complete
                UIALogger.logDebug("verifyNotActive is skipping the default screenIsActive function");
                return true;
            };
        }

        return this;
    };


    /**
     * Create a new action in the appmap with the given name.
     *
     * All following implementation / parameter definitions will be associated with this action.
     *
     * @param actionName the desired screen name
     * @param desc the description of this action that will be used for logging purposes
     * @return this
     */
    appmap.withNewAction = function(actionName, desc) {
        // we need this hack to prevent problems with the above isCorrectScreen hack --
        //  so that we don't change the original reference, we rebuild the {targetname : function} map manually
        var frozen = function(k) { return appmap.lastScreenActiveFn[k]; };
        var isActiveMap = {};
        for (var k in appmap.lastScreenActiveFn) {
            isActiveMap[k] = frozen(k);
        }

        // we add screen params to the action so that we can deal in actions alone
        appmap.lastAction = {
            name: actionName,
            isCorrectScreen: isActiveMap,
            appName: appmap.lastAppName,
            screenName: appmap.lastScreenName,
            actionFn: {},
            description: desc,
            params: {}
        };
        appmap.lastActionName = actionName;
        if (debugAppmap) UIALogger.logDebug("  adding action " + appmap.lastActionName);
        appmap.lastScreen[appmap.lastActionName] = appmap.lastAction;
        return this;
    };


   /**
     * whether an action exists
     *
     * @param appName the app to look in
     * @param screenName tge screen to look in
     * @param actionName the screen name to test
     * @return bool
     */
    appmap.hasAction = function(appName, screenName, actionName) {
        return appmap.hasScreen(appName, screenName) && (actionName in appmap.apps[appName][screenName]);
    }


    /**
     * All following implementation / parameter definitions will be associated with this screen
     *
     * @param appName the desired app name
     * @return this
     */
    appmap.augmentAction = function(actionName) {
        if (debugAppmap) UIALogger.logDebug("  augmenting action " + actionName);
        appmap.lastAction = appmap.lastScreen[actionName];
        appmap.lastActionName = actionName;
        return this;
    }

    /**
     * Create a new action in the appmap with the given name if it does not already exist.
     *
     * All following implementation / parameter definitions will be associated with this action.
     *
     * @param actionName the desired screen name
     * @param desc the description of this action that will be used for logging purposes
     * @return this
     */
    appmap.withAction = function(actionName, desc) {
        return appmap.hasAction(appmap.lastAppName, appmap.lastScreenName, actionName) ? appmap.augmentAction(actionName) : appmap.withNewAction(actionName, desc);
    }

    /**
     * Set the function that will carry out the current action on the given target device
     *
     * targetName is optional; if omitted, the function will be used for all target devices
     *
     * @param actFn function that should be executed when the current action is requested to run
     * @param targetName optional the name of the target device (e.g. "iPhone", "iPad")
     * @return this
     */
    appmap.withImplementation = function(actFn, targetName) {
        targetName = targetName === undefined ? "default" : targetName;

        // catch implementations for nonexistent targets
        if ("default" != targetName && !(targetName in appmap.lastAction.isCorrectScreen)) {
            var targets = [];
            for (var k in appmap.lastAction.isCorrectScreen) {
                targets.push(k);
            }
            var msg = "Screen " + appmap.lastAppName + "." + appmap.lastScreenName;
            msg += " only has defined targets: '" + targets.join("', '") + "' but tried to add an implementation";
            msg += " for target device '" + targetName + "' in action '" + appmap.lastActionName + "'";
            throw new appmap.SetupException(msg);
        }

        if (debugAppmap) UIALogger.logDebug("   adding implementation on " + targetName);
        appmap.lastAction.actionFn[targetName] = actFn;
        return this;
    }

    /**
     * Define a new parameter in the latest action with the given attributes
     *
     * @param paramName the name of the parameter
     * @param desc a description of the parameter
     * @param required bool whether the parameter is required for the action
     * @param useInSummary whether the value of the parameter should be logged when the action executes
     */
    appmap.withParam = function(paramName, desc, required, useInSummary) {
        if (debugAppmap) UIALogger.logDebug("   adding parameter " + paramName);
        useInSummmary = useInSummary === undefined ? false : useInSummary;
        appmap.lastAction.params[paramName] = {
            description: desc,
            required: required,
            useInSummary: useInSummary
        };
        return this;
    };

    /**
     * return an array of all defined apps
     */
    appmap.getApps = function() {
        var ret = [];
        for (d in appmap.apps) ret.push(d);
        return ret;
    };

    /**
     * return an array of all defined screens for the given app
     *
     * @param app the app name
     */
    appmap.getScreens = function(app) {
        var ret = [];
        for (s in appmap.apps[app]) ret.push(s);
        return ret;
    };

    /**
     * Returns Markdown string describing all the apps, screens, targets, actions, implementations, and parameters
     */
    appmap.toMarkdown = function () {
        var ret = ["The following apps are defined in the Illuminator AppMap:"];

        // formatting the title, making good looking markdown
        var title = function (rank, text) {
            // insert blank lines before the title
            var total = 4;
            for (var i = 0; i <= (total - rank); ++i) {
                ret.push("");
            }

            switch (rank) {
            case 1:
                ret.push(text);
                ret.push(Array(Math.max(10, text.length) + 1).join("="));
                break;
            case 2:
                ret.push(text);
                ret.push(Array(Math.max(10, text.length) + 1).join("-"));
                break;
            default:
                ret.push(Array(rank + 1).join("#") + " " + text);
            }
        };

        // if an action is defined on the same targets as its parent screen (not just a subset)
        var onSameTargets = function (action) {
            if ("default" == Object.keys(action.actionFn)[0]) return true;
            for (d in action.isCorrectScreen) if (undefined === action.actionFn[d]) return false;
            return true;
        };

        // iterate over apps
        var apps = Object.keys(appmap.apps).sort();
        for (var i = 0; i < apps.length; ++i) {
            var appName = apps[i];
            var app = appmap.apps[appName];
            title(1, appName);
            ret.push("This app has the following screens:");

            // iterate over screens
            var screens = Object.keys(app).sort();
            for (var j = 0; j < screens.length; ++j) {
                var scnName = screens[j];
                var scn = app[scnName];
                title(2, scnName);

                // just use the first action on the screen to get the targets - from isCorrectScreen map
                var screenTargets = "`" + Object.keys(scn[Object.keys(scn)[0]].isCorrectScreen).join("`, `") + "`";
                ret.push("Defined for " + screenTargets + ", with the following actions:");
                ret.push(""); // need blank line before bulleted lists

                // iterate over actions
                var actions = Object.keys(scn).sort();
                for (var k = 0; k < actions.length; ++k) {
                    var actName = actions[k];
                    var act = scn[actName];
                    var actionTargets = onSameTargets(act) ? "" : " `" + Object.keys(act.actionFn).join("`, `") + "`";
                    var parms = Object.keys(act.params).length == 0 ? "" : " (parameterized)";
                    ret.push("* **" + actName + "**" + parms + actionTargets + ": " + act.description);

                    // iterate over parameters
                    var params = Object.keys(act.params).sort();
                    for (var m = 0; m < params.length; ++m) {
                        var paramName = params[m];
                        var par = act.params[paramName];
                        ret.push("    * `" + paramName + "`" + (par.required ? "" : " (optional)") + ": " + par.description);
                    }
                }

            }
        }

        return ret.join("\n");
    };


    // create an action builder to enable easy one-liners for common actions
    //  intended use is to say var ab = appmap.actionBuilder.makeAction;
    //        then in appmap: .withImplementation(ab.verifyElement.visibility({name: "blah"}))
    appmap.actionBuilder = {};
    appmap.actionBuilder.makeAction = {};
    appmap.actionBuilder.makeAction.verifyElement = {};
    appmap.actionBuilder.makeAction.element = {};
    appmap.actionBuilder.makeAction.selector = {};
    appmap.actionBuilder.makeAction.screenIsActive = {};


    /**
     * Internal function for getting child elements and raising the appropriate errors
     *
     * @param selector the selector to get the element
     * @param retryDelay optional integer, if provided and the selector fails then the selector will be retried
     */
    appmap.actionBuilder._getElement = function(selector, retryDelay) {
        try {
            return target().getOneChildElement(selector);
        } catch (e) {
            // it's possible that the selector returned multiple things, so re-raise that
            if ("function" != typeof (selector)) {
                var elems = target().getChildElements(selector);
                if (Object.keys(getUniqueElements(elems)).length > 1) throw e;
            }

            // one consequence-free failure allowed if retryDelay was specified
            if (retryDelay === undefined) throw e;
            delay(retryDelay);
            return target().getOneChildElement(selector);
        }
    };


    /**
     * Internal function for building actions that verify predicate functions
     *
     * @param selector the element to select
     * @param elemName the name of what is being selected
     * @param predicateFn the function (taking an element as an argument, returning a boolean) that should be evaluated
     * @param predicateDesc the name of the predicate function, for logging purposes
     * @param retryDelay optional integer, if provided and the selector fails then the selector will be retried
     * @return a function (taking an object with fields {expected: boolean} as its only argument) that asserts the predicate
     */
    appmap.actionBuilder.makeAction.verifyElement._predicate = function(selector, elemName, predicateFn, predicateDesc, retryDelay) {
        return function(parm) {
            var elem = appmap.actionBuilder._getElement(selector, retryDelay);

            // prevent any funny business with integer comparisons
            if ((predicateFn(elem) == true) != (parm.expected == true)) {
                throw new IlluminatorRuntimeVerificationException("Element " + elemName + " failed predicate " + predicateDesc
                                                                  + " (expected value: " + parm.expected + ")");
            }
        };
    };


    /**
     * Internal function for building actions that interact with elements
     *
     * @param selector the element to select
     * @param elemName the name of what is being selected
     * @param workFn the function (taking an element as an argument) that should be performed
     * @param retryDelay optional integer, if provided and the selector fails then the selector will be retried
     * @param return a function (taking no arguments) that executes the work function on the selected element
     */
    appmap.actionBuilder.makeAction.element._interaction = function(selector, elemName, workFn, retryDelay) {
        return function(parm) {
            var elem = appmap.actionBuilder._getElement(selector, retryDelay);
            workFn(elem, parm);
        };
    };



    /**
     * create a screenIsActive function by looking for a specific element.
     *
     * @param screenName the screen name, for logging purposes
     * @param elementName what is being selected, for logging purposes
     * @param selector the selector to watch
     * @param timeout how long to wait
     * @return a no-argument function that returns a boolean
     */
    appmap.actionBuilder.makeAction.screenIsActive.byElement = function (screenName, elementName, selector, timeout) {
        switch (typeof timeout) {
        case "number": break;
        default: throw new appmap.SetupException("makeAction.screenIsActive.byElement got a bad timeout value: (" + (typeof timeout) + ") " + timeout);
        }

        return function () {
            try {
                target().waitForChildExistence(timeout, true, elementName, selector);
                return true;
            } catch (e) {
                UIALogger.logDebug("screenIsActive.byElement function for " + screenName + " got error: " + e);
                return false;
            }
        };
    };


    /**
     * build an action function that verifies whether an element is enabled
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a function that takes an object with fields {expected: boolean} as its argument
     */
    appmap.actionBuilder.makeAction.verifyElement.enabled = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.verifyElement._predicate(selector, elemName, function (elem) {
            return elem.isEnabled();
        }, "isEnabled", retryDelay);
    };


    /**
     * build an action function that verifies element existence
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a function that takes an object with fields {expected: boolean} as its argument
     */
    appmap.actionBuilder.makeAction.verifyElement.existence = function(selector, elemName, retryDelay) {
        return function(parm) {
            var msg = "";
            try {
                var elem = appmap.actionBuilder._getElement(selector, retryDelay);
                if (parm.expected === true) return;
            } catch (e) {
                msg = ": " + e.toString();
                if (!(parm.expected === true)) return;
            }
            throw new IlluminatorRuntimeVerificationException("Element " + elemName + " failed existence check "
                                                              + "(expected: " + parm.expected + ")" + msg);
        };
    };


    /**
     * build an action function that verifies element visibility
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a function that takes an object with fields {expected: boolean} as its argument
     */
    appmap.actionBuilder.makeAction.verifyElement.visibility = function(selector, elemName, retryDelay) {
        return function(parm) {
            var msg = "";
            try {
                var elem = appmap.actionBuilder._getElement(selector, retryDelay);
                if ((elem && elem.isVisible()) == parm.expected) return;
            } catch (e) {
                msg = ": " + e.toString();
                if (!(parm.expected === true)) return;
            }
            throw new IlluminatorRuntimeVerificationException("Element " + elemName + " failed visibility check "
                                                              + "(expected: " + parm.expected + ")" + msg);
        };
    };

    /**
     * build an action function that verifies element editability
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a function that takes an object with fields {expected: boolean} as its argument
     */
    appmap.actionBuilder.makeAction.verifyElement.editability = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.verifyElement._predicate(selector, elemName, function (elem) {
            return elem.checkIsEditable();
        }, "isEditable", retryDelay);
    };

    /**
     * build an action function that taps an element
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a no-argument function
     */
    appmap.actionBuilder.makeAction.element.tap = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element._interaction(selector, elemName, function (elem, parm) {
            elem.tap()
        }, retryDelay);
    };

    /**
     * build an action function that vtaps an element
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a no-argument function
     */
    appmap.actionBuilder.makeAction.element.vtap = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element._interaction(selector, elemName, function (elem, parm) {
            elem.vtap(4)
        }, retryDelay);
    };

    /**
     * build an action function that svtaps an element
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a no-argument function
     */
    appmap.actionBuilder.makeAction.element.svtap = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element._interaction(selector, elemName, function (elem, parm) {
            elem.svtap(4)
        }, retryDelay);
    };

    /**
     * build an action function that types text in an element
     *
     * @param selector reference to the element
     * @param elemName the name of what we are looking for
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @return a function that takes an object with fields {text: string, clear: boolean} as its argument
     */
    appmap.actionBuilder.makeAction.element.typeString = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element._interaction(selector, elemName, function (elem, parm) {
            elem.typeString(parm.text, parm.clear === true);
        }, retryDelay);
    };

    /**
     * build an action function that checks the existence of a child selector
     *
     * @param retryDelay optional integer how long to wait before a retry if selector fails
     * @param parentSelector reference to the parent element
     * @return a function that takes an object with fields {selector: selector} as its argument
     */
    appmap.actionBuilder.makeAction.selector.verifyExists = function(retryDelay, parentSelector) {
        return function(parm) {
            var fullSelector;
            if (undefined === parentSelector || !(parentSelector) || 0 == Object.keys(parentSelector).length) {
                fullSelector = parm.selector;
            } else {
                fullSelector = parentSelector;
                fullSelector.push(parm.selector);
            }

            //TODO: possibly cache the parentSelector element and use that instead of target()

            var elemsObj = target().getChildElements(fullSelector);
            // one retry allowed
            if (Object.keys(elemsObj).length == 0 && retryDelay !== undefined && retryDelay >= 0) {
                elemsObj = target().getChildElements(fullSelector);
            }

            // react to number of elements
            switch (Object.keys(elemsObj).length) {
            case 0: throw new IlluminatorRuntimeFailureException("Selector found no elements: " + JSON.stringify(fullSelector));
            case 1: return;
            default: UIALogger.logMessage("Selector (for existence) found multiple elements: " + JSON.stringify(elemsObj));
            }
        };
    };

}).call(this);
