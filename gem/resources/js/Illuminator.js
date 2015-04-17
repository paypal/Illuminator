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

    // send test definitions back to framework
    if (!host().writeToFile(config.buildArtifacts.automatorScenarioJSON,
                            JSON.stringify(automator.toScenarioObject(false), null, "    ")))
    {
        throw new IlluminatorSetupException("Could not save necessary build artifact to " +
                                            config.buildArtifacts.automatorScenarioJSON);
    }
    notifyIlluminatorFramework("Saved scenario definitions to: " + config.buildArtifacts.automatorScenarioJSON);

    // run app-specific callback
    if (!automator._executeCallback("onInit", {entryPoint: config.entryPoint}, false, false)) return;

    // choose entry point and go
    switch (config.entryPoint) {

    case "runTestsByName":
        automator.runNamedScenarios(config.automatorScenarioNames, config.automatorSequenceRandomSeed);
        break;

    case "runTestsByTag":
        if (0 == (config.automatorTagsAny.length + config.automatorTagsAll.length + config.automatorTagsNone.length)) {
            UIALogger.logMessage("No tag sets (any / all / none) were specified, so printing some information about defined scenarios");
            automator.logInfo();
            notifyIlluminatorFramework("Successful launch");
        } else {
            automator.runTaggedScenarios(config.automatorTagsAny,
                                         config.automatorTagsAll,
                                         config.automatorTagsNone,
                                         config.automatorSequenceRandomSeed);
        }
        break;

    case "describe":
        notifyIlluminatorFramework("Successful launch");
        var appMapMarkdownPath    = config.buildArtifacts.appMapMarkdown;
        var automatorMarkdownPath = config.buildArtifacts.automatorMarkdown;
        var automatorJSONPath     = config.buildArtifacts.automatorJSON;
        host().writeToFile(appMapMarkdownPath, appmap.toMarkdown());
        UIALogger.logMessage("Wrote AppMap definitions to " + appMapMarkdownPath);
        host().writeToFile(automatorMarkdownPath, automator.toMarkdown());
        UIALogger.logMessage("Wrote automator definitions to " + automatorMarkdownPath);
        host().writeToFile(automatorJSONPath, JSON.stringify(automator.toScenarioObject(true), null, "    "));
        UIALogger.logMessage("Wrote automator definition data to " + automatorJSONPath);
        break;

    default:
        notifyIlluminatorFramework("Successful launch");
        throw new IlluminatorSetupException("Unknown Illuminator entry point specified: " + config.entryPoint);
    }
}


/**
 * Send a message back to the log analyzers (ruby)
 *
 * @param message string
 */
function notifyIlluminatorFramework(message) {
    UIALogger.logDebug(config.saltinel + " " + message + " " + config.saltinel);
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

    var diff_pngPath = IlluminatorScriptsDirectory + "/diff_png.sh";
    UIATarget.localTarget().captureScreenWithName(captureTitle);

    var screenshotFile  = captureTitle + ".png";
    var screenshotPath  = config.screenshotDir + "/" + screenshotFile;
    var compareFileBase = config.screenshotDir + "/compared_" + captureTitle;

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
    .withImplementation(actionCompareScreenshotToMaster)

    .withAction("testAsAction", "Execute an entire test as one action")
    .withParam("test", "The function that performs the entire test")
    .withImplementation(function (parm) { parm.test(); });
