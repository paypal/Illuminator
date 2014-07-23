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

    appmap.apps = {};       // all possible apps, keyed by string
    var lastApp;            // state variable for building app
    var lastAppName;        // name of last app
    var lastScreen;         // state variable for building screen
    var lastScreenName;     // name of last screen
    var lastAction;         // state variable for building action
    var lastActionName;     // name of last action
    var lastScreenActiveFn; // action function map of last screen

    // create a new app in the appmap with the given name
    appmap.createApp = function(appName) {
        appmap.lastApp = {}; // screens is empty
        appmap.apps[appName] = appmap.lastApp;
        appmap.lastScreen = null;
        appmap.lastAction = null;
        return this;
    };

    // whether an app exists
    appmap.hasApp = function(appName) {
        return appName in appmap.apps;
    };

    // function to re-start editing a app
    appmap.augmentApp = function(appName) {
        appmap.lastApp = appmap.apps[appName];
        appmap.lastAppName = appName;
        return this;
    };

    // function to do the right thing
    appmap.createOrAugmentApp = function(appName) {
        return appmap.hasApp(appName) ? appmap.augmentApp(appName) : appmap.createApp(appName);
    }


    // create a new screen in the latest app, with the given name
    appmap.withNewScreen = function(screenName) {
        appmap.lastScreen = {};
        appmap.lastScreenName = screenName;
        appmap.lastScreenActiveFn = {};
        appmap.lastAction = null;

        appmap.lastApp[appmap.lastScreenName] = appmap.lastScreen;
        if (debugAppmap) UIALogger.logDebug(" adding screen " + appmap.lastScreenName);

        return this;
    };

    // augment an existing screen
    appmap.augmentScreen = function(screenName) {
        appmap.lastScreenName = screenName;
        appmap.lastScreen = appmap.lastApp[appmap.lastScreenName];
        if (debugAppmap) UIALogger.logDebug(" augmenting screen " + appmap.lastScreenName);
        return this;
    }

    // whether a screen exists
    appmap.hasScreen = function(appName, screenName) {
        return appmap.hasApp(appName) && (screenName in appmap.apps[appName]);
    }

    // function to do the right thing
    appmap.withScreen = function(screenName) {
        return appmap.hasScreen(appmap.lastAppName, screenName) ? appmap.augmentScreen(screenName) : appmap.withNewScreen(screenName);
    }


    // enable the screen on a given device by setting the isActiveFn()
    //  isActiveFn() should return true if the screen is currently both visible and accessible
    appmap.onDevice = function(deviceName, isActiveFn) {
        var lastScreenName = appmap.lastScreenName;
        if (debugAppmap) UIALogger.logDebug("  on Device " + deviceName);
        appmap.lastScreenActiveFn[deviceName] = isActiveFn;

        appmap.withAction("verifyIsActive", "Null op to verify that the " + appmap.lastScreenName + " screen is active");
        // slightly hacky, withImplementation expects actions to come AFTER all the onDevice calls
        appmap.lastAction.isCorrectScreen[deviceName] = isActiveFn;
        appmap.withImplementation(function() {}, deviceName);

        appmap.withAction("verifyNotActive", "Verify that the " + appmap.lastScreenName + " screen is NOT active")
        // slightly hacky, withImplementation expects actions to come AFTER all the onDevice calls
        appmap.lastAction.isCorrectScreen[deviceName] = isActiveFn;
        appmap.withImplementation(function() {
                      if (isActiveFn()) throw "Failed assertion that '" + lastScreenName + "' is NOT active ";
                  }, deviceName);

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


    // create a new action in the latest screen, with the given name, description, and function
    appmap.withNewAction = function(actionName, desc) {
        // we need this hack to prevent problems with the above isCorrectScreen hack --
        //  so that we don't change the original reference, we rebuild the {devicename : function} map manually
        var frozen = function(k) { return appmap.lastScreenActiveFn[k]; };
        var isActiveMap = {};
        for (var k in appmap.lastScreenActiveFn) {
            isActiveMap[k] = frozen(k);
        }

        // we add screen params to the action so that we can deal in actions alone
        appmap.lastAction = {
            name: actionName,
            isCorrectScreen: isActiveMap,
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

    // augment an existing action
    appmap.augmentAction = function(actionName) {
        if (debugAppmap) UIALogger.logDebug("  augmenting action " + actionName);
        appmap.lastAction = appmap.lastScreen[actionName];
        appmap.lastActionName = actionName;
        return this;
    }

    // whether an action exists
    appmap.hasAction = function(appName, screenName, actionName) {
        return appmap.hasScreen(appName, screenName) && (actionName in appmap.apps[appName][screenName]);
    }

    // do the right thing
    appmap.withAction = function(actionName, desc) {
        return appmap.hasAction(appmap.lastAppName, appmap.lastScreenName, actionName) ? appmap.augmentAction(actionName) : appmap.withNewAction(actionName, desc);
    }


    // create a new parameter in the latest action, with the given varname and description
    // optionally, useInSummary to indiciate whether the parameter should be printed in the step description
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


    // create a new implementation for the latest action
    // actFn will take one optional argument -- an associative array
    appmap.withImplementation = function(actFn, deviceName) {
        deviceName = deviceName === undefined ? "default" : deviceName;

        // catch implementations for nonexistent devices
        if ("default" != deviceName && !(deviceName in appmap.lastAction.isCorrectScreen)) {
            var devices = [];
            for (var k in appmap.lastAction.isCorrectScreen) {
                devices.push(k);
            }
            var msg = "Screen " + appmap.lastAppName + "." + appmap.lastScreenName;
            msg += " only has defined devices: '" + devices.join("', '") + "' but tried to add an implementation";
            msg += " for device '" + deviceName + "' in action '" + appmap.lastActionName + "'";
            throw msg;
        }

        if (debugAppmap) UIALogger.logDebug("   adding implementation on " + deviceName);
        appmap.lastAction.actionFn[deviceName] = actFn;
        return this;
    }

    appmap.getApps = function() {
        var ret = [];
        for (d in appmap.apps) ret.push(d);
        return ret;
    };

    appmap.getScreens = function(app) {
        var ret = [];
        for (s in appmap.apps[app]) ret.push(s);
        return ret;
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

    // create a screenIsActive function
    appmap.actionBuilder.makeAction.screenIsActive.byElement = function (screenName, elementName, selector, timeout) {
        switch (typeof timeout) {
        case "number": break;
        default: throw "makeAction.screenIsActive.byElement got a bad timeout value: (" + (typeof timeout) + ") " + timeout;
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

    // resolve an element
    appmap.actionBuilder.getElement = function(selector, retryDelay) {
        var err;
        try {
            return target().getOneChildElement(selector);
        } catch (e) {
            err = e;
            // it's possible that the selector returned multiple things, so re-raise that
            if ("function" != typeof (selector)) {
                var elems = target().getChildElements(selector);
                if (Object.keys(getUniqueElements(elems)).length > 1) throw e;
            }

            // one consequence-free failure allowed if retryDelay was specified
            if (retryDelay === undefined) throw err;
            delay(retryDelay);
            return target().getOneChildElement(selector);
        }
    };


    // build an existence function action
    // selector is for resolveElement
    // elemName is the name for logging purposes
    // retryDelay is an optional delay to pause and retry if the selector comes up empty handed
    //
    // return an action that takes 'expected' (bool) as a parameter
    appmap.actionBuilder.makeAction.verifyElement.existence = function(selector, elemName, retryDelay) {
        return function(parm) {
            var msg = "";
            try {
                var elem = appmap.actionBuilder.getElement(selector, retryDelay);
                if (parm.expected === true) return;
            } catch (e) {
                msg = ": " + e.toString();
                if (!(parm.expected === true)) return;
            }
            throw "Element " + elemName + " failed existence check (expected: " + parm.expected + ")" + msg;
        };
    };


    // build a predicate function action
    // selector is for resolveElement
    // elemName is the name for logging purposes
    // predicate_fn is a function that takes an element as an argument
    // predicateDesc is a description of the function for logging
    // retryDelay is an optional delay to pause and retry if the selector comes up empty handed
    //
    // return an action that takes 'expected' (bool) as a parameter
    appmap.actionBuilder.makeAction.verifyElement.predicate = function(selector, elemName, predicate_fn, predicateDesc, retryDelay) {
        return function(parm) {
            var elem = appmap.actionBuilder.getElement(selector, retryDelay);

            // prevent any funny business with integer comparisons
            if ((predicate_fn(elem) == true) != (parm.expected == true)) {
                throw "Element " + elemName + " failed predicate " + predicateDesc + " (expected value: " + parm.expected + ")";
            }
        };
    };

    // build an element method action
    // selector is for resolveElement
    // elemName is the name for logging purposes
    // work_fn is a function that takes an element as an argument plus
    // workDesc is a description of the function for logging
    // retryDelay is an optional delay to pause and retry if the selector comes up empty handed
    appmap.actionBuilder.makeAction.element.act = function(selector, elemName, work_fn, retryDelay) {
        return function(parm) {
            var elem = appmap.actionBuilder.getElement(selector, retryDelay);
            work_fn(elem, parm);
        };
    };


    // return an action that takes 'expected' (bool) as a parameter
    appmap.actionBuilder.makeAction.verifyElement.visibility = function(selector, elemName, retryDelay) {
        return function(parm) {
            var msg = "";
            try {
                var elem = appmap.actionBuilder.getElement(selector, retryDelay);
                if ((elem && elem.isVisible()) == parm.expected) return;
            } catch (e) {
                msg = ": " + e.toString();
                if (!(parm.expected === true)) return;
            }
            throw "Element " + elemName + " failed visibility check (expected: " + parm.expected + ")" + msg;
        };
    };

    // return an action that takes 'expected' (bool) as a parameter
    appmap.actionBuilder.makeAction.verifyElement.editability = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.verifyElement.predicate(selector, elemName, function (elem) {
            return elem.checkIsEditable();
        }, "isEditable", retryDelay);
    };

    // return an action that takes 'expected' (bool) as a parameter
    appmap.actionBuilder.makeAction.verifyElement.enabled = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.verifyElement.predicate(selector, elemName, function (elem) {
            return elem.isEnabled();
        }, "isEnabled", retryDelay);
    };

    // return an action that takes no parameters
    appmap.actionBuilder.makeAction.element.tap = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element.act(selector, elemName, function (elem, parm) {
            elem.tap()
        }, retryDelay);
    };

    // return an action that takes no parameters
    appmap.actionBuilder.makeAction.element.vtap = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element.act(selector, elemName, function (elem, parm) {
            elem.vtap(4)
        }, retryDelay);
    };

    appmap.actionBuilder.makeAction.element.svtap = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element.act(selector, elemName, function (elem, parm) {
            elem.svtap(4)
        }, retryDelay);
    };

    // return an action that takes "text" and "clear" (bool) as parameters
    appmap.actionBuilder.makeAction.element.typeString = function(selector, elemName, retryDelay) {
        return appmap.actionBuilder.makeAction.element.act(selector, elemName, function (elem, parm) {
            elem.typeString(parm.text, parm.clear === true);
        }, retryDelay);
    };

    // return an action that takes a selector as a parameter
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
            case 0: throw "Selector found no elements: " + JSON.stringify(fullSelector);
            case 1: return;
            default: UIALogger.logMessage("Selector (for existence) found multiple elements: " + JSON.stringify(elemsObj));
            }
        };
    };

}).call(this);
