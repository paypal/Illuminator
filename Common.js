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

function dumpElements(elements) {
    for (var i in elements) {
        UIALogger.logDebug(elements[i].toString());
    }
}


// given a UI element accessor function, throw an error if the element's existence
//   doesn't match what the expectedVisibility was.  "name" is for logging purposes
function verifyUIElementVisibility(name, targetAccessorFn, expectedVisibility, timeout) {
    timeout = timeout === undefined ? 1 : timeout;
    var visibility;
    try {
        var theItem = target.waitUntilAccessorSuccess(targetAccessorFn, timeout, name);
        theItem.waitUntilVisible(timeout);
        visibility = true;
    } catch (e) {
        visibility = false;
    }

    if (expectedVisibility != visibility) {
        throw ("''" + name + "'' has visiblity '" + visibility +
               "' but expected '" + expectedVisibility + "'");
    }
}

// given a UI element accessor function, throw an error if the element's editabilty
//   doesn't match what the editabilty (keyboard use) was.  "name" is for logging purposes
function verifyUIElementEditability(name, targetAccessorFn, expectedEditability) {

    var editability;
    try {
        var theItem = target.waitUntilAccessorSuccess(targetAccessorFn, 1, name);
        theItem.tap();

        target.frontMostApp().keyboard().waitUntilVisible(2);
        editability = true;
    } catch (e) {
        editability = false;
    }

    if (expectedEditability != editability) {
        throw ("''" + name + "'' has edit-ability '" + editability +
               "' but expected '" + expectedEditability + "'");
    }

}

function mkActionForItemVisibility(name, targetAccessorFn) {
    return function(parm) {
        return verifyUIElementVisibility(name, targetAccessorFn, parm.expected);
    };
}

function mkActionForItemEditability(name, targetAccessorFn) {
    return function(parm) {
        return verifyUIElementEditability(name, targetAccessorFn, parm.expected);
    };
}

function mkActionForNavbarButton(navbar_name, button_name) {
    return function () {
        var button;
        var triesLeft = 2;
        while (triesLeft > 0) {
            triesLeft--;
            button = target.waitUntilAccessorSuccess(function(targ) {
                    if (navbar_name) {
                        return targ.frontMostApp().mainWindow().navigationBars()[navbar_name].buttons()[button_name];
                    } else {
                        return targ.frontMostApp().mainWindow().navigationBar().buttons()[button_name];
                    }
                }, 10, "'" + button_name + "' button in navbar of '" + navbar_name);
            button.waitUntilVisible(5);
            try {
                button.tap();
                return;
            } catch (e) {
                if (triesLeft > 0) {
                    UIALogger.logDebug("Error tapping (will retry) " + button_name + " in " + navbar_name + ": " + e);
                } else {
                    throw e;
                }
            }
        }
    }
}

function makeActionForVisibilityWithSelector(description, selector) {
    return function (param) {
        if (typeof(selector) === "function") {
            selector = selector(param);
        }
        verifyUIElementVisibility(description, function (targ) {
            var elts = $(selector);
            if (elts && elts.length) { return elts[0]; }
            return null;
        }, param.expected);
    };
}

function makeActionForPredicateOnElement(description, selector, predicate) {
    return function (param) {
        if (typeof(selector) === "function") {
            selector = selector(param);
        }
        verifyUIElementVisibility(description, function (targ) {
            var elts = $(selector);
            if (elts && elts.length) { return elts[0]; }
            return null;
        }, true);
        if (!predicate($(selector)[0], param)) {
            throw new Error("Predicate " + description + " did not match " + selector);
        }
    };
}

function makeActionForTapWithSelector(description, selector) {
    return function () {
        verifyUIElementVisibility(description, function (targ) {
            var elts = $(selector);
            if (elts && elts.length) { return elts[0]; }
            return null;
        }, true);
        $(selector).tap();
    }
}

function makeActionToEnterTextWithSelector(description, elementKey) {
    return function (param) {
        $(elementKey).input(param.text);
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

function actionCompareScreenshotToTemplate(parm) {
    var templatePath = parm.templatePath;
    var captureTitle = parm.captureTitle;

    var diff_pngPath = automatorRoot + "/scripts/diff_png.rb";
    UIATarget.localTarget().captureScreenWithName(captureTitle);

    screenshotDir  = automatorRoot + "/buildArtifacts/UIAutomationReport/Run 1"; // it's always Run 1
    screenshotFile = captureTitle + ".png";
    screenshotPath = screenshotDir + "/" + screenshotFile;
    comparePngPath = screenshotDir + "/compared_" + screenshotFile;
    compareGifPath = screenshotDir + "/compared_" + captureTitle + ".gif";

    UIALogger.logDebug("Diffing images, this may take tens of seconds: " + templatePath + " :: " + screenshotPath);
    var output = target.host().performTaskWithPathArgumentsTimeout("/usr/bin/ruby",
                                                                   [diff_pngPath, templatePath, screenshotPath, comparePngPath],
                                                                   120);

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
    if (!outputObj["pixels changed"]) throw "actionCompareScreenshotToTemplate: diff_png.rb failed to produce 'pixels changed' output";

    // if output has no differences, return
    var wrongPixels = parseInt(outputObj["pixels changed"]);
    if (0 == wrongPixels) return;

    // generate an animated gif of the changes
    var output = target.host().performTaskWithPathArgumentsTimeout("/usr/local/bin/convert",
                                                                   ["-delay", "50",
                                                                    templatePath, screenshotPath,
                                                                    "-loop", "0",
                                                                    compareGifPath],
                                                                   120);

    throw ["Screenshot differed from", templatePath,
           "by", wrongPixels, "pixels. ",
           "Comparison image saved to:", comparePngPath,
           " and comparison animation saved to:", compareGifPath].join(" ");
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

    .withAction("fail", "Unconditionally fail the current test for debugging purposes")
    .withImplementation(function() { throw "purposely-thrown exception to halt the test scenario"; })

    .withAction("verifyScreenshot", "Validate a screenshot against a png template of the expected view")
    .withParam("templatePath", "The path to the file that is considered the 'expected' view", true, true)
    .withParam("captureTitle", "The title of the screenshot to capture", true, true)
    .withImplementation(actionCompareScreenshotToTemplate);
