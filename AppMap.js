// AppMap.js
//
// creates 'appmap' which can build and store app definitions
// apps have screens
// screens have actions
// actions have parameters
// actions have device-specific implementations

#import "../screens/AllScreens.js";

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
        if (debugAppmap) UIALogger.logDebug("  on Device " + deviceName);
        appmap.lastScreenActiveFn[deviceName] = isActiveFn;

        appmap.withAction("verifyIsActive", "Null op to verify that the " + appmap.lastScreenName + " screen is active")
              .withImplementation(function() {}, deviceName);

        appmap.withAction("verifyNotActive", "Verify that the " + appmap.lastScreenName + " screen is NOT active")
              .withImplementation(function() {
                      if (isActiveFn()) throw "Failed assertion that '" + appmap.lastScreenName + "' is NOT active ";
                  }, deviceName);

        // now modify verifyNotActive's isCorrectScreen array to always return true.  slighly hacky.
        // this is because the meat of the function runs in our generated action
        for (var d in appmap.lastAction.isCorrectScreen) {
            if (d == "dumpProperties" || d == "getMethods") continue;
            appmap.lastAction.isCorrectScreen[d] = function () { return true; };
        }

        return this;
    };


    // create a new action in the latest screen, with the given name, description, and function
    appmap.withNewAction = function(actionName, desc) {
        // we add screen params to the action so that we can deal in actions alone
        appmap.lastAction = {
            name: actionName,
            isCorrectScreen: appmap.lastScreenActiveFn,
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
                if (k == "dumpProperties" || k == "getMethods") continue;
                devices.push(k);
            }
            var msg = "Screen " + appmap.lastAppName + "." + appmap.lastScreenName;
            msg += " only has devices: '" + devices.join("', '") + "' but tried to add an implementation";
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


}).call(this);
