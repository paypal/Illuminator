// Config.js
//
// loads configuration from a generated file, provides sensible defaults

#import "buildArtifacts/environment.js"

(function() {

    var root = this,
        config = null;

    // put config in namespace of importing code
    if (typeof exports !== 'undefined') {
        config = exports;
    } else {
        config = root.config = {};
    }

    config.implementation = 'iPhone';
    config.automatorTagsAny = []; // run all by default
    config.automatorTagsAll = []; // none by default
    config.automatorTagsNone = [];
    config.automatorSequenceRandomSeed = undefined;

    config.setField = function (key, value) {
        switch (key) {
        case "automatorSequenceRandomSeed":
            config.automatorSequenceRandomSeed = parseInt(value);
            break;
        case "customConfig":
            config.customConfig = getPlistData(value)
            break;
        default:
            config[key] = value;
        }
    }


    // expected keys, and whether they are required
    var expectedKeys = {
        "entryPoint": true,
        "implementation": true,
        "automatorDesiredSimDevice": true,
        "automatorDesiredSimVersion": true,
        "hardwareID": true,
        "automatorTagsAny": false,
        "automatorTagsAll": false,
        "automatorTagsNone": false,
        "automatorScenarioNames": false,
        "automatorSequenceRandomSeed": false,
        "customConfig": false,
    };

    // read config and create temp dir
    var jsonConfig = getPlistData(automatorRoot + "/buildArtifacts/generatedConfig.plist");
    target().host().performTaskWithPathArgumentsTimeout("/bin/mkdir", ["-p", automatorRoot + "/buildArtifacts/js-tmp"], 5);
    config.tmpDir = automatorRoot + "/buildArtifacts/js-tmp";

    // check for keys we don't expect
    for (var k in jsonConfig) {
        if (expectedKeys[k] === undefined) {
            UIALogger.logWarning("Config got unexpected key " + k);
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

    // set the custom config from the plist
    try {
        config.setCustomConfig(jsonConfig.customConfig);
    } catch (e) {
        UIALogger.logMessage("Didn't read (optional) customConfig from generated config");
    }


}).call(this);
