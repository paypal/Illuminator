#import "buildArtifacts/environment.js"
// these are here so that everything just imports from Illuminator.js
#import "Extensions.js";
#import "Config.js";
#import "AppMap.js";
#import "Automator.js";
#import "Bridge.js";


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

    switch (config.entryPoint) {

    case "runTestsByTag":
        if (0 == (config.automatorTagsAny.length + config.automatorTagsAll.length + config.automatorTagsNone.length)) {
            UIALogger.logMessage("No tag sets (any / all / none) were defined, so printing some information about defined scenarios");
            automator.logInfo();
        } else {
            automator.runSupportedScenarios(config.automatorTagsAny, config.automatorTagsAll, config.automatorTagsNone, config.automatorSequenceRandomSeed);
        }
        break;

    case "describe":
        var now = Math.round(getTime());
        var appMapMarkdownPath = config.tmpDir + "/appMap-" + now + ".md";
        var automatorMarkdownPath = config.tmpDir + "/automator-" + now + ".md";
        writeToFile(appMapMarkdownPath, appmap.toMarkdown());
        UIALogger.logMessage("Wrote AppMap definitions to " + appMapMarkdownPath);
        writeToFile(automatorMarkdownPath, automator.toMarkdown());
        UIALogger.logMessage("Wrote automator definitions to " + automatorMarkdownPath);
        break;

    default:
        throw "Unknown Illuminator entry point specified: " + config.entryPoint;
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
        throw "Simulator version " + ver + " is running, but generated-config.js " +
            "specifies " + config.automatorDesiredSimVersion;
    }
}

/**
 * Write data to a file
 *
 * @param path the path that should be (over)written
 * @data the data of the file to write
 */
function writeToFile(path, data) {
    var chunkSize = Math.floor(262144 * 0.74) - (path.length + 100); // `getconf ARG_MAX`, adjusted for b64

    if (data.length < chunkSize) {
        var b64data = Base64.encode(data);
        UIALogger.logDebug("Writing " + data.length + " bytes to " + path + " as " + b64data.length + " bytes of b64");
        target().host().performTaskWithPathArgumentsTimeout("/bin/sh", ["-c", "echo $0 | base64 -D -o $1", b64data, path], 5);
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
            target().host().performTaskWithPathArgumentsTimeout("/bin/sh", ["-c", "echo $0 | base64 -D -o $1", b64data, chunkFile], 5);
            chunkFiles.push(chunkFile);
        }

        // concatenate all the chunks
        var unchunkCmd = "cat \"" + chunkFiles.join("\" \"") + "\" > $0";
        UIALogger.logDebug("Concatenating and deleting " + chunkFiles.length + " chunks, writing " + path);
        target().host().performTaskWithPathArgumentsTimeout("/bin/sh", ["-c", unchunkCmd, path], 5);
        target().host().performTaskWithPathArgumentsTimeout("/bin/rm", chunkFiles, 5);
    }

}

function getPlistData(path) {
    var jsonOutput;
    var scriptPath = automatorRoot + "/scripts/plist_to_json.sh";
    UIALogger.logDebug("Running " + scriptPath + " '" + path + "'");

    var output = target().host().performTaskWithPathArgumentsTimeout(scriptPath, [path], 30);
    try {
        jsonOutput = JSON.parse(output.stdout);
    } catch(e) {
        throw ("plist_to_json.sh gave bad JSON: ```" + output.stdout + "```");
    }

    return jsonOutput;
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
