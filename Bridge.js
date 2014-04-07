// Bridge.js
//
// gives access to (some) native methods in the app, bypassing the UI

#import "Base64.js";

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

    var bridgeCallNum = 0; // the call ID of a request in progress
    var bridgeWaitTime = 6; // seconds to wait for response from a bridge call

    // some structures to make function names less wordy
    bridge.nextNetworkRequest = {};

    bridge.runNativeMethod = function(selector, arguments_obj, expectsReturnValue) {

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

        var scriptPath = automatorRoot + "/scripts/UIAutomationBridge.rb";
        taskArguments.push(scriptPath);

        taskArguments.push("--callUID=" + UID)
        
        if (config.hardwareID !== undefined) {
            taskArguments.push("--hardwareID=" + config.hardwareID);
        }
        
        if (selector !== undefined) {
            taskArguments.push("--selector=" + selector);
        }

        if (arguments !== undefined) {
            taskArguments.push("--b64argument=" + Base64.encode(arguments));
        }

        if (expectsReturnValue !== undefined) {
            taskArguments.push("--expectsReturnValue");
        }

        UIALogger.logDebug("Bridge waiting for acknowledgment of UID '"
                           + UID + "'" + " from $ /usr/bin/ruby "
                           + taskArguments.join(" "));

        output = target.host().performTaskWithPathArgumentsTimeout("/usr/bin/ruby", taskArguments, 500);


        if (output) {
            if ("" == output.stdout.trim()) {
                UIALogger.logWarning("Ruby may not be working, try $ ruby " + taskArguments.join(" "));
                throw "Bridge got back an empty/blank string instead of JSON";
            }
            try {
                jsonOutput = JSON.parse(output.stdout);
            } catch(e) {
                throw ("Bridge got back bad JSON: " + output.stdout);
            }
        } else {
            jsonOutput = null;
        }

        var ruby_check   = jsonOutput["ruby_check"];
        var status_check = jsonOutput["status_check"];
        var response     = jsonOutput["response"];

        // this sanity check verifies that the ruby script was able to execute properly
        if (ruby_check === undefined) {
            throw "Bridge failed ruby check for '" + UID + "'.  Check ruby errors by running bridge script manually.";
        }

        // this status check tries to figure out whether the connection to the sim was successful
        if (response === undefined) {
            if (status_check === undefined)    throw "Bridge status check missing for '" + UID + "'.";
            if (status_check == "initialized") throw "Bridge appears not to have connected to app";
            if (status_check == "errbacked")   throw "Bridge errbacked with '" + jsonOutput["error_message"] + "'.";
            if (status_check == "streamed")    throw "Bridge received data but did not understand the response";
        }


        // this checks whether we got the response we were supposed to
        if (response["callUID"] == UID) {
            UIALogger.logDebug ("Bridge got expected return value: '" + response["callUID"] + "'");
        } else {
            UIALogger.logDebug ("Bridge got UNEXPECTED return value: '" + response["callUID"] + "'"
                                + " instead of: '" + UID + "'");
        }

        return response["result"];

    };

    bridge.makeActionFunction = function(selector, expectsReturnValue) {
        return function(parm) {
            bridge.runNativeMethod(selector, parm, expectsReturnValue);
        };
    }

    // passes a fake response from resources/savedServerResponses
    //  where responseId is the serverResponseName_responseId) -- optional
    bridge.nextNetworkRequest.returnFakeResponse = function(method, parms, responseId) {
        if (undefined === parms) parms = {};

        // build up parms with response ID and method
        if (undefined !== responseId) {
            parms["responseId"] = responseId;
        }
        parms["method"] = method;
        UIALogger.logDebug(JSON.stringify(parms));
        bridge.runNativeMethod("returnFakeResponseForNextNetworkRequestToMethod:", parms);
    };

    // convenient wrapper for fake response functions for use in appmap actions
    bridge.nextNetworkRequest.mkReturnFakeResponseFn = function(method, responseId) {
        return function(parm) {
            bridge.nextNetworkRequest.returnFakeResponse(method, parm, responseId);
        };
    };


    bridge.nextNetworkRequest.failWithServerError = function(method, errorCode, parameters) {
        parameters["method"] = method;
        parameters["errorCode"] = errorCode;

        bridge.runNativeMethod("failNextNetworkRequestToMethodWithServerError:", parameters);
    };


    bridge.nextNetworkRequest.failWithNetworkError = function(method,
                                                              nsErrorCode,
                                                              httpStatusCode,
                                                              parameters) {
        parameters["method"] = method;
        parameters["nsErrorCode"] = nsErrorCode;
        parameters["httpStatusCode"] = httpStatusCode;

        bridge.runNativeMethod("failNextNetworkRequestToMethodWithNetworkError:", parameters);
    };


}).call(this);
