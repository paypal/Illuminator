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

    config.setField = function (key, value) {
        switch (key) {
        case "automatorSequenceRandomSeed":
            config.automatorSequenceRandomSeed = parseInt(value);
            break;
        case "customJSConfigPath":
            try {
                config.customConfig = getJSONData(value)
            } catch (e) {
                throw new IlluminatorSetupException(key + " of '" + value + "' couldn't be parsed as JSON; error was: " + e);
            }
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
        "hardwareID": false,
        "automatorTagsAny": false,
        "automatorTagsAll": false,
        "automatorTagsNone": false,
        "automatorScenarioNames": false,
        "automatorSequenceRandomSeed": false,
        "customJSConfigPath": false,
    };

    var jsonConfig = getJSONData(IlluminatorBuildArtifactsDirectory + "/IlluminatorGeneratedConfig.json");
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

    // create temp dir
    var tmpDir = IlluminatorBuildArtifactsDirectory + "/js-tmp";
    target().host().performTaskWithPathArgumentsTimeout("/bin/mkdir", ["-p", tmpDir], 5);
    config.tmpDir = tmpDir;

}).call(this);
