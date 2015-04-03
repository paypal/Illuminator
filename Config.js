// Config.js
//
// loads configuration from a generated file, provides sensible defaults

(function() {

    var root = this,
        config = null;

    // put config in namespace of importing code
    if (typeof exports !== 'undefined') {
        config = exports;
    } else {
        config = root.config = {};
    }

    config.implementation = 'Unspecified_iOS_Device';
    config.automatorTagsAny = []; // run all by default
    config.automatorTagsAll = []; // none by default
    config.automatorTagsNone = [];
    config.automatorSequenceRandomSeed = undefined;
    config.buildArtifacts = {};

    config.setField = function (key, value) {
        switch (key) {
        case "automatorSequenceRandomSeed":
            config.automatorSequenceRandomSeed = parseInt(value);
            break;
        default:
            config[key] = value;
        }
    }


    // expected keys, and whether they are required
    var expectedKeys = {
        "saltinel": true,
        "entryPoint": true,
        "implementation": true,
        "automatorDesiredSimDevice": true,
        "automatorDesiredSimVersion": true,
        "hardwareID": false,
        "targetDeviceID": true,
        "xcodePath": true,
        "automatorTagsAny": false,
        "automatorTagsAll": false,
        "automatorTagsNone": false,
        "automatorScenarioNames": false,
        "automatorSequenceRandomSeed": false,
        "automatorScenarioOffset": true,
        "customConfig": false,
    };

    var jsonConfig = host().readJSONFromFile(IlluminatorBuildArtifactsDirectory + "/IlluminatorGeneratedConfig.json");
    // check for keys we don't expect
    for (var k in jsonConfig) {
        if (expectedKeys[k] === undefined) {
            UIALogger.logMessage("Config got unexpected key " + k);
        }
    }

    // test for keys we DO expect
    for (var k in expectedKeys) {
        if (jsonConfig[k] !== undefined) {
            config.setField(k, jsonConfig[k]);
        } else if (expectedKeys[k]) {
            UIALogger.logWarning("Couldn't read " + k + " from generated config");
        }
    }

    // find the directory where screenshots will go
    IlluminatorInstrumentsOutputDirectory
    // handles globbing of a path that may have spaces in it, assumes newest directory is the run directory
    var findMostRecentDirCmd = 'eval ls -1td "' + IlluminatorInstrumentsOutputDirectory + '/Run*" | head -n 1';
    var output = host().shellAsFunction("/bin/bash", ["-c", findMostRecentDirCmd], 5);
    config.screenshotDir = output.stdout;

    // create temp dir for build artifacts and note path names
    var tmpDir = IlluminatorBuildArtifactsDirectory + "/UIAutomation-outputs";
    target().host().performTaskWithPathArgumentsTimeout("/bin/mkdir", ["-p", tmpDir], 5);
    config.buildArtifacts.root = tmpDir;
    config.buildArtifacts.appMapMarkdown        = tmpDir + "/appMap.md";
    config.buildArtifacts.automatorMarkdown     = tmpDir + "/automator.md";
    config.buildArtifacts.automatorJSON         = tmpDir + "/automator.json";
    config.buildArtifacts.automatorScenarioJSON = tmpDir + "/automatorScenarios.json";
    config.buildArtifacts.intendedTestList      = tmpDir + "/intendedTestList.json";

}).call(this);
