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

    config.device = 'iPhone';
    config.stage = 'fake';
    config.tagsAny = []; // run all by default
    config.tagsAll = []; // none by default
    config.tagsNone = [];
    config.automatorSequenceRandomSeed = undefined;

    // setter for device
    config.setDevice = function(device) {
        config.device = device;
    };

    // setter for hardwareID
    config.setHardwareID = function(hardwareID) {
        config.hardwareID = hardwareID;
    };
    // setter for stage
    config.setStage = function(stage) {
        config.stage = stage;
    };

    // setter for tagsAny
    config.setTagsAny = function(tagsAny) {
        config.tagsAny = tagsAny;
    };

    // setter for tagsAll
    config.setTagsAll = function(tagsAll) {
        config.tagsAll = tagsAll;
    };

    // setter for tagsNone
    config.setTagsNone = function(tagsNone) {
        config.tagsNone = tagsNone;
    };

    // setter for automatorSequenceRandomSeed
    config.setAutomatorSequenceRandomSeed = function(asrs) {
        config.automatorSequenceRandomSeed = parseInt(asrs);
    };

    // attempt to read config -- look for VARIABLES IN GLOBAL SCOPE
    try {
        config.setDevice(device);
    } catch (e) {
        UIALogger.logMessage("Couldn't read device from generated config");
    }

    try {
        config.setHardwareID(hardwareID)
    } catch (e) {
    }

    try {
        config.setStage(stage);
    } catch (e) {
        UIALogger.logMessage("Couldn't read stage from generated config");
    }

    try {
        config.setTagsAny(automatorTagsAny);
    } catch (e) {
        UIALogger.logMessage("Couldn't read automatorTagsAny from generated config");
    }

    try {
        config.setTagsAll(automatorTagsAll);
    } catch (e) {
        UIALogger.logMessage("Couldn't read automatorTagsAll from generated config");
    }

    try {
        config.setTagsNone(automatorTagsNone);
    } catch (e) {
        UIALogger.logMessage("Couldn't read automatorTagsNone from generated config");
    }

    try {
        config.setAutomatorSequenceRandomSeed(automatorSequenceRandomSeed);
    } catch (e) {
        UIALogger.logMessage("Didn't read (optional) automatorSequenceRandomSeed from generated config");
    }

    // read config from json string
    config.readFromJSONString = function(stringJSON) {
        config.readFromObject(JSON.parse(stringJSON));
    };

    // read config from object
    config.readFromObject = function(obj) {

        for (var key in obj) {
            switch (key) {
            case "device":
            config.setDevice(obj[key]);
            break;
            case "stage":
            config.setStage(obj[key]);
            case "tags":
            config.setTags(obj[key]);
            case "attributes":
            config.setAttributes(obj[key]);
            default:
            UIALogger.logDebug("Ignoring unrecognized config key '" + key + "'");
            }
        }
    };


}).call(this);
