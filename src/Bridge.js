// Bridge.js
//
// gives access to (some) native methods in the app, bypassing the UI


var debugBridge = false;

(function() {

    var root = this,
        bridge = null;

    // put bridge in namespace of importing code
    if (typeof exports !== 'undefined') {
        bridge = exports;
    } else {
        bridge = root.bridge = {};
    }

    // Exception classes
    bridge.SetupException = makeErrorClass("BridgeSetupException");


    var bridgeCallNum = 0; // the call ID of a request in progress
    var bridgeWaitTime = 6; // seconds to wait for response from a bridge call

    bridge.runNativeMethod = function(selector, arguments_obj) {

        var arguments = undefined;
        if (arguments_obj !== undefined) arguments = JSON.stringify(arguments_obj);

        var UID = "Bridge_call_" + (++bridgeCallNum).toString();
        UIALogger.logDebug(["Bridge running native method via '",
                            UID,
                            "': selector='",
                            selector,
                            "', arguments='",
                            arguments,
                            "'"
                            ].join(""));

        var taskArguments = [];

        var scriptPath = IlluminatorRootDirectory + "/scripts/UIAutomationBridge.rb";
        taskArguments.push(scriptPath);

        taskArguments.push("--callUID=" + UID)

        if (config.isHardware) {
            taskArguments.push("--hardwareID=" + config.targetDeviceID);
        }

        if (selector !== undefined) {
            taskArguments.push("--selector=" + selector);
        }

        if (arguments !== undefined) {
            taskArguments.push("--b64argument=" + Base64.encode(arguments));
        }

        UIALogger.logDebug("Bridge waiting for acknowledgment of UID '"
                           + UID + "'" + " from $ /usr/bin/ruby "
                           + taskArguments.join(" "));

        output = target().host().performTaskWithPathArgumentsTimeout("/usr/bin/ruby", taskArguments, 500);


        if (output) {
            if ("" == output.stdout.trim()) {
                UIALogger.logWarning("Ruby may not be working; to diagnose, run this same command in a terminal: "
                                     + "$ ruby " + taskArguments.join(" "));
                throw new bridge.SetupException("Bridge got back an empty/blank string instead of JSON");
            }
            try {
                jsonOutput = JSON.parse(output.stdout);
            } catch(e) {
                throw new IlluminatorRuntimeFailureException("Bridge got back bad JSON: " + output.stdout);
            }
        } else {
            jsonOutput = null;
        }

        var success       = jsonOutput["success"];
        var bridgeFailMsg = jsonOutput["message"];
        var response      = jsonOutput["response"];

        // this status check tries to figure out whether the connection to the sim was successful
        if (!success) {
            throw new IlluminatorRuntimeFailureException("Bridge call failed: " + bridgeFailMsg);
        }

        return response["result"];

    };

    bridge.makeActionFunction = function(selector) {
        return function(parm) {
            bridge.runNativeMethod(selector, parm);
        };
    }

}).call(this);
