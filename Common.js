#import "contrib/tuneup_js/tuneup.js";
#import "buildArtifacts/environment.js"
// these are here so that everything just imports from Common.js
#import "Config.js";
#import "AppMap.js";
#import "Automator.js";
#import "Bridge.js";
#import "contrib/mechanic.js";

var target = UIATarget.localTarget();
var mainWindow = target.frontMostApp().mainWindow();


function delay(seconds) {
    target.delay(seconds);
}

function getTime() {
    var output = target.host().performTaskWithPathArgumentsTimeout("/bin/date", ["+%s"], 5);
    return parseInt(output.stdout);
}

function isMatchingVersion(input, prefix, major, minor, rev) {
    var findStr = prefix + major;

    if (undefined !== minor) {
        findStr += "." + minor;
        if (undefined !== rev) {
            findStr += "." + rev;
        }
    }

    return input.indexOf(findStr) > -1;
}

function isSimVersion(major, minor, rev) {
    return isMatchingVersion(target.systemVersion(), "", major, minor, rev);
}

function assertDesiredSimVersion() {
    var ver = target.systemVersion();
    if (("iOS " + ver).indexOf(config.automatorDesiredSimVersion) == -1) {
        throw "Simulator version " + ver + " is running, but generated-config.js " +
            "specifies " + config.automatorDesiredSimVersion;
    }
}


// for compatibility with iOS 6 that doesn't name cells, buttons, etc
function getNamedItemFromContainer(itemContainerView,
                                   itemArrayAccessor,
                                   itemMatchPredicate,
                                   itemSelector,
                                   name) {

    var items = itemArrayAccessor(itemContainerView);
    for (var i = 0; i < items.length; ++i) {
        var item = items[i];
        if (itemMatchPredicate(item)) return itemSelector(item);
    }

    return null;
}

function getNamedCellFromContainer(cellContainerView, name) {
    var ret = getNamedItemFromContainer(cellContainerView,
                                        function(c) { return c.cells(); },
                                        function(i) {
                                            var ii = i.elements()[0];
                                            return ii.isNotNil() && ii.name() == name;
                                        },
                                        function(i) { return i.elements()[0]; },
                                        name);
    return ret !== null ? ret : cellContainerView.cells().firstWithName(name).elements().firstWithName(name);
}

/**
 * Resolve an expression to a single UIAElement
 *
 * Selector can be one of the following:
 * 1. A function that takes UIATarget as an argument and returns a UIAElement.
 * 2. An object of critera to satisfy mainWindow.find() .
 * 3. An array of objects containing UIAElement.find() criteria; elem = mainWindow.find(arr[0]).find(arr[1])...
*/
function resolveElement(selector) {
    // there are multiple ways to access certain elements; collapse these entries
    var getUniqueElements = function (elemObject) {
        var ret = {};
        for (var i in elemObject) {
            var elem = elemObject[i];
            var found = false;
            for (var j in ret) {
                if (found) continue;
                if (ret[j] == elem) {
                    found = true;
                }
            }

            if (!found) {
                ret[i] = elem;
            }
        }
        return ret;
    };

    // return one element from an associative array of possibly-duplicate entries, raise error if distinct entries != 1
    var getOneElement = function (elemObject) {
        var uniq = getUniqueElements(elemObject);
        var size = Object.keys(elemObject).length;
        if (size != 1) {
            var msg = "resolveElement: expected 1 element, received " + size.toString() + " {";
            for (var k in elemObject) {
                msg += "\n    " + k + ": " + elemObject[k].toString();
            }
            msg += "\n}";
            throw msg;
        }

        for (var k in elemObject) {
            UIALogger.logDebug("Selector found object with canonical name: " + k);
            return elemObject[k];
        }
    }

    // perform a find in several stages
    var segmentedFind = function(selectorArray) {
        var intermElems = {"mainWindow": mainWindow}; //intermediate elements
        // go through all selectors
        for (var i = 0; i < selectorArray.length; ++i) {
            var tmp = {};
            // expand search on each intermediate element using current selector
            for (var k in intermElems) {
                var newFrontier = intermElems[k].find(selectorArray[i], k);
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
    switch(typeof selector) {
    case "function":
        return selector(target);
    case "object":
        if (selector instanceof Array) {
            return getOneElement(segmentedFind(selector));
        } else {
            return getOneElement(segmentedFind([selector]));
        }
    default:
        throw "resolveSelector received undefined input type of " + (typeof selector).toString();
    }
}

function getPlistData(path) {

    var jsonOutput;
    var scriptPath = automatorRoot + "/scripts/plist_to_json.sh";
    UIALogger.logDebug("Running " + scriptPath + " '" + path + "'");

    var output = target.host().performTaskWithPathArgumentsTimeout(scriptPath, [path], 30);
    try {
        jsonOutput = JSON.parse(output.stdout);
    } catch(e) {
        throw ("plist_to_json.sh gave bad JSON: ```" + output.stdout + "```");
    }

    return jsonOutput;
}

/**
 * Build an action on an element based on an element selector and a function to apply
 *
 * Selector is passed to resolveElement
 */
function makeActionOnElement(selector, work_fn) {
    return function(param) {
        var elem = resolveElement(selector);
        work_fn(elem, param);
    }
}

function actionCompareScreenshotToMaster(parm) {
    var masterPath   = parm.masterPath;
    var maskPath     = parm.maskPath;
    var captureTitle = parm.captureTitle;
    var delayCapture = parm.delay === undefined ? 0.4 : parm.delay;

    target.delay(delayCapture); // wait for any animations to settle

    var diff_pngPath = automatorRoot + "/scripts/diff_png.sh";
    UIATarget.localTarget().captureScreenWithName(captureTitle);

    var screenshotDir   = automatorRoot + "/buildArtifacts/UIAutomationReport/Run 1"; // it's always Run 1
    var screenshotFile  = captureTitle + ".png";
    var screenshotPath  = screenshotDir + "/" + screenshotFile;
    var compareFileBase = screenshotDir + "/compared_" + captureTitle;

    var output = target.host().performTaskWithPathArgumentsTimeout("/bin/sh",
                                                                   [diff_pngPath,
                                                                    masterPath,
                                                                    screenshotPath,
                                                                    maskPath,
                                                                    compareFileBase],
                                                                   20);

    // turn the output into key/value pairs separated by ":"
    var outputArr = output.stdout.split("\n");
    var outputObj = {};
    for (var i = 0; i < outputArr.length; ++i) {
        var sp = outputArr[i].split(": ", 2)
        if (sp.length == 2) {
            outputObj[sp[0]] = sp[1];
        }
    }

    // sanity check
    if (!outputObj["pixels changed"]) throw "actionCompareScreenshotToMaster: diff_png.sh failed to produce 'pixels changed' output";

    // if differences are outside tolerances, throw errors
    var allPixels = parseInt(outputObj["pixels (total)"]);
    var wrongPixels = parseInt(outputObj["pixels changed"]);

    var allowedPixels = parm.allowedPixels === undefined ? 0 : parm.allowedPixels;
    var errmsg = "";
    if (allowedPixels < wrongPixels) {
        errmsg = ["Screenshot differed from", masterPath,
                  "by", wrongPixels, "pixels. ",
                  "Comparison image saved to:", compareFileBase + ".png",
                  " and comparison animation saved to:", compareFileBase + ".gif"].join(" ");

        if (parm.deferFailure === true) {
            automator.deferFailure(errmsg);
        } else {
            throw errmsg;
        }
    }

    if (parm.allowedPercent !== undefined) {
        var wrongPct = 100.0 * wrongPixels / allPixels;
        if (wrongPct > parm.allowedPercent) {
            errmsg = ["Screenshot differed from", masterPath,
                      "by", wrongPct, "%. ",
                      "Comparison image saved to:", compareFileBase + ".png",
                      " and comparison animation saved to:", compareFileBase + ".gif"].join(" ");

            if (parm.deferFailure === true) {
            } else {
                throw errmsg;
            }
        }
    }
}

function actionLogAccessors(parm) {
    if (parm !== undefined && parm.delay !== undefined) {
        delay(parm.delay);
    }
    var visibleOnly = parm !== undefined && parm.visibleOnly === true;
    UIALogger.logDebug(mainWindow.elementAccessorDump("mainWindow", visibleOnly));
}


////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions - common capabilities
////////////////////////////////////////////////////////////////////////////////////////////////////
appmap.createOrAugmentApp("ios-automator").withScreen("do")
    .onDevice("iPhone", function() { return true; })
    .onDevice("iPad", function() { return true; })

    .withAction("delay", "Delay a given amount of time")
    .withParam("seconds", "Number of seconds to delay", true, true)
    .withImplementation(function(parm) {delay(parm.seconds);})

    .withAction("debug", "Print the results of a debug function")
    .withParam("debug_fn", "Function returning a string", true)
    .withImplementation(function(parm) { UIALogger.logMessage(parm.debug_fn()); })

    .withAction("logTree", "Log the UI element tree")
    .withImplementation(function() { UIATarget.localTarget().logElementTree(); })

    .withAction("logAccessors", "Log the list of valid element accessors")
    .withParam("visibleOnly", "Whether to log only the visible elements", false, true)
    .withParam("delay", "Number of seconds to delay before logging", false, true)
    .withImplementation(actionLogAccessors)

    .withAction("fail", "Unconditionally fail the current test for debugging purposes")
    .withImplementation(function() { throw "purposely-thrown exception to halt the test scenario"; })

    .withAction("verifyScreenshot", "Validate a screenshot against a png template of the expected view")
    .withParam("masterPath", "The path to the file that is considered the 'expected' view", true, true)
    .withParam("maskPath", "The path to the file that masks variable portions of the 'expected' view", true, true)
    .withParam("captureTitle", "The title of the screenshot to capture", true, true)
    .withParam("delay", "The amount of time to delay before taking the screenshot", false, true)
    .withParam("allowedPixels", "The maximum number of pixels that are allowed to differ (default 0)", false, true)
    .withParam("allowedPercent", "The maximum percentage of pixels that are allowed to differ (default 0)", false, true)
    .withParam("deferFailure", "Whether to defer a failure until the end of the test", false, true)
    .withImplementation(actionCompareScreenshotToMaster);
