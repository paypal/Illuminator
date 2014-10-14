/**
 * Main entry point
 *
 * There are no arguments to this function, because it will be controlled by Config arguments
 * and invoked by testAutomatically.js (a generated file).  See the documentation on how to
 * set up and run Illuminator.
 */
function IlluminatorIlluminate() {
    // initial sanity checks
    assertDesiredSimVersion();

    if (!automator._executeCallback("onInit", {entryPoint: config.entryPoint}, false, false)) return;

    switch (config.entryPoint) {

    case "runTestsByTag":
        if (0 == (config.automatorTagsAny.length + config.automatorTagsAll.length + config.automatorTagsNone.length)) {
            UIALogger.logMessage("No tag sets (any / all / none) were defined, so printing some information about defined scenarios");
            automator.logInfo();
        } else {
            automator.runTaggedScenarios(config.automatorTagsAny, config.automatorTagsAll, config.automatorTagsNone, config.automatorSequenceRandomSeed);
        }
        break;

    case "runTestsByName":
        automator.runNamedScenarios(config.automatorScenarioNames, config.automatorSequenceRandomSeed);
        break;

    case "describe":
        var now = Math.round(getTime());
        var appMapMarkdownPath = config.tmpDir + "/appMap-" + now + ".md";
        var automatorMarkdownPath = config.tmpDir + "/automator-" + now + ".md";
        var automatorJSONPath = config.tmpDir + "/automator-" + now + ".json";
        writeToFile(appMapMarkdownPath, appmap.toMarkdown());
        UIALogger.logMessage("Wrote AppMap definitions to " + appMapMarkdownPath);
        writeToFile(automatorMarkdownPath, automator.toMarkdown());
        UIALogger.logMessage("Wrote automator definitions to " + automatorMarkdownPath);
        writeToFile(automatorJSONPath, JSON.stringify(automator.toScenarioObject(), null, "    "));
        UIALogger.logMessage("Wrote automator definition data to " + automatorJSONPath);
        break;

    default:
        throw new IlluminatorSetupException("Unknown Illuminator entry point specified: " + config.entryPoint);
    }
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
    return isMatchingVersion(target().systemVersion(), "", major, minor, rev);
}

function assertDesiredSimVersion() {
    var ver = target().systemVersion();
    if (("iOS " + ver).indexOf(config.automatorDesiredSimVersion) == -1) {
        throw new IlluminatorSetupException("Simulator version " + ver + " is running, but generated-config.js " +
            "specifies " + config.automatorDesiredSimVersion);
    }
}

function actionCompareScreenshotToMaster(parm) {
    var masterPath   = parm.masterPath;
    var maskPath     = parm.maskPath;
    var captureTitle = parm.captureTitle;
    var delayCapture = parm.delay === undefined ? 0.4 : parm.delay;

    delay(delayCapture); // wait for any animations to settle

    var diff_pngPath = automatorRoot + "/scripts/diff_png.sh";
    UIATarget.localTarget().captureScreenWithName(captureTitle);

    var screenshotDir   = automatorRoot + "/buildArtifacts/UIAutomationReport/Run 1"; // it's always Run 1
    var screenshotFile  = captureTitle + ".png";
    var screenshotPath  = screenshotDir + "/" + screenshotFile;
    var compareFileBase = screenshotDir + "/compared_" + captureTitle;

    var output = target().host().performTaskWithPathArgumentsTimeout("/bin/sh",
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
    if (!outputObj["pixels changed"]) {
        throw new IlluminatorRuntimeVerificationException("actionCompareScreenshotToMaster: diff_png.sh failed to produce 'pixels changed' output");
    }

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
            throw new IlluminatorRuntimeVerificationException(errmsg);
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
                throw new IlluminatorRuntimeVerificationException(errmsg);
            }
        }
    }
}

function actionLogAccessors(parm) {
    if (parm !== undefined && parm.delay !== undefined) {
        delay(parm.delay);
    }
    var visibleOnly = parm !== undefined && parm.visibleOnly === true;
    UIALogger.logDebug(mainWindow().elementReferenceDump("mainWindow", visibleOnly));
}

function actionCaptureElementTree(parm) {
    target().captureImageTree(parm.imageBaseName);
}

/**
 * Set the value of a date text field by manipulating the picker wheels - THIS IS AN OBJECT METHOD
 *
 * All values are numeric and (should) work across languages.  All values are optional.
 *
 * (this) an element
 * @param year optional integer
 * @param month optional integer
 * @param day optional integer
 */
var pickDateYMD = function (year, month, day) {
    var wheel = target().frontMostApp().windows()[1].pickers()[0].wheels();
    if (year !== undefined) wheel[2].selectValue(year.toString());
    if (month !== undefined) wheel[0].selectValue(wheel[0].values()[month - 1]); // read localized value, set that value
    if (day !== undefined) wheel[1].selectValue(day.toString());
};

/**
 * Set the value of a date text field by manipulating the picker wheels - THIS IS AN OBJECT METHOD
 *
 * All values are numeric and (should) work across languages.  All values are optional.
 *
 * (this) an element
 * @param year optional integer
 * @param month optional integer
 */
var pickDateYM = function (year, month) {
    var wheel = target().frontMostApp().windows()[1].pickers()[0].wheels();
    if (year !== undefined) wheel[1].selectValue(year.toString());
    if (month !== undefined) wheel[0].selectValue(wheel[0].values()[month - 1]); // read localized value, set that value
};



////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions - common capabilities
////////////////////////////////////////////////////////////////////////////////////////////////////
appmap.createOrAugmentApp("Illuminator").withScreen("do")
    .onTarget(config.implementation, function() { return true; })
    // onTarget(config.implementation...) is a HACK.
    // Illuminator doesn't define implementations, so we use what we're given.
    //   (i.e. you shouldn't copy/paste this example into your project code)

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

    .withAction("captureElementTree", "Take individual screenshots of all screen elements")
    .withParam("imageBaseName", "The base name for the image files", true, true)
    .withImplementation(actionCaptureElementTree)

    .withAction("fail", "Unconditionally fail the current test for debugging purposes")
    .withImplementation(function() { throw new IlluminatorRuntimeVerificationException("purposely-thrown exception to halt the test scenario"); })

    .withAction("verifyScreenshot", "Validate a screenshot against a png template of the expected view")
    .withParam("masterPath", "The path to the file that is considered the 'expected' view", true, true)
    .withParam("maskPath", "The path to the file that masks variable portions of the 'expected' view", true, true)
    .withParam("captureTitle", "The title of the screenshot to capture", true, true)
    .withParam("delay", "The amount of time to delay before taking the screenshot", false, true)
    .withParam("allowedPixels", "The maximum number of pixels that are allowed to differ (default 0)", false, true)
    .withParam("allowedPercent", "The maximum percentage of pixels that are allowed to differ (default 0)", false, true)
    .withParam("deferFailure", "Whether to defer a failure until the end of the test", false, true)
    .withImplementation(actionCompareScreenshotToMaster);


// create a custom input method for the date picker
appmap.createInputMethod("yearMonthDayPicker",
                         "A set of 3 picker wheels to select a date",
                         function () {
                             return isNotNilElement(target().frontMostApp().windows()[1].pickers()[0]);
                         },
                         function (targ) {
                             return target().frontMostApp().windows()[1];
                         })
    .withFeature("pickDate", pickDateYMD)
    .withFeature("done", function () {
        target().frontMostApp().windows()[1].toolbar().buttons()["Done"].tap();
    });

appmap.createInputMethod("yearMonthPicker",
                         "A set of 2 picker wheels to select a date",
                         function () {
                             return isNotNilElement(target().frontMostApp().windows()[1].pickers()[0]);
                         },
                         function (targ) {
                             return target().frontMostApp().windows()[1];
                         })
    .withFeature("pickDate", pickDateYM)
    .withFeature("done", function () {
        target().frontMostApp().windows()[1].toolbar().buttons()["Done"].tap();
    });
