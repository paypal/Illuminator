// Automator.js
//
// creates 'automator' which can build and run scenarios

var debugAutomator = false;

/**
 * The exception thrown when a 'fail' is used.
 *
 * @param message - reason the test failed/aborted
 */
function FailureException(message) {
    this.name = 'FailureException';
    this.message = message;
    this.toString = function() {
        return this.name + ': "' + this.message + '"';
    };
}

/**
 * Fail the test with the given message
 */
function fail(message) {
  throw new FailureException(message);
}

(function() {

    var root = this,
        automator = null;

    // put automator in namespace of importing code
    if (typeof exports !== 'undefined') {
        automator = exports;
    } else {
        automator = root.automator = {};
    }

    automator.callback = {
        init: function() { UIALogger.logDebug("Warning: running default automator 'init' callback"); },
        prescenario: function() { UIALogger.logDebug("Warning: running default automator 'prescenario' callback"); }
    };

    automator.didInit = false;

    automator.scenarios = {
        _untagged: []
    }; // each of scenarios[tag] is an array of scenarios
    automator.allScenarios = []; // flat list of scenarios
    automator.lastScenario = null; // state variable for building scenarios of steps
    automator.allScenarioNames = {}; // for ensuring name uniqueness

    automator.lastRunScenario = null;

    // a few functions to handle callbacks (automator customization)
    automator.setCallbackInit = function(fn) {
        automator.callback["init"] = fn;
    };

    automator.setCallbackPreScenario = function(fn) {
        automator.callback["prescenario"] = fn;
    };

    automator.checkInit = function() {
        if (!automator.didInit) {
            automator.didInit = true;
            automator.callback["init"]();
        }
    };


    // to allow deferred failures
    automator._deferredFailures = [];

    automator.deferFailure = function(err) {
        UIALogger.logDebug("Deferring an error: " + err);
        automator.logScreenInfo();

        if (automator._state.internal["currentStepName"] && automator._state.internal["currentStepNumber"]) {
            var msg = "Step " + automator._state.internal["currentStepNumber"];
            msg += " (" + automator._state.internal["currentStepName"] + "): ";
            automator._deferredFailures.push(msg + err);
        } else {
            automator._deferredFailures.push("<Undefined step>: " + err);
        }
    }

    // functions to handle automator state -- ways for scenario steps to register side effects
    automator._state = {};
    automator._state.external = {};

    automator.resetState = function() {
        automator._state.external = {};
        automator._state.internal = {};
    };

    automator.setState = function(key, value) {
        automator._state.external[key] = value;
    };

    automator.hasState = function(key) {
        return undefined !== automator._state.external[key];
    };

    automator.getState = function(key, defaultValue) {
        if (automator.hasState(key)) return automator._state.external[key];

        UIALogger.logDebug("Automator state '" + key + "' not found, returning default");
        return defaultValue;
    };


    // create a blank scenario with:
    //  tags -- an array of labels denoting named groups for scenarios to be run (OR'd)
    //
    //  example: tags = ['alpha', 'beta', 'fake', 'nohardware']
    //    the test will run if ['alpha', 'gamma'] are specified as tagsAny
    //     but it will not run if ['fake', 'YES hardware'] are specified as tagsAll
    automator.createScenario = function(scenarioName, tags, attributes) {
        if (automator.allScenarioNames[scenarioName]) throw "Can't createScenario '" + scenarioName + "', because that name already exists";
        automator.allScenarioNames[scenarioName] = true;

        automator.lastScenario = {
            title: scenarioName,
            steps: []
        };
        if (tags === undefined) tags = ["_untagged"]; // always have a tag
        if (attributes !== undefined) {
            UIALogger.logMessage("Scenario attributes are DEPRECATED -- just combine them with the tags.  in scenario: " + scenarioName);
            for (var i = 0; i < attributes.length; ++i) {
                tags.push(attributes[i]);
            }
        }

        if (debugAutomator) {
            UIALogger.logDebug(["Automator creating scenario '", scenarioName, "'",
                                " [", tags.join(", "), "]",
                                ].join(""));
        }

        automator.lastScenario.tags     = [];
        automator.lastScenario.tags_obj = {}; // convert tags to object
        for (var i = 0; i < tags.length; ++i) {
            var t = tags[i];
            automator.lastScenario.tags.push(t);
            automator.lastScenario.tags_obj[t] = true;
        }

        automator.allScenarios.push(automator.lastScenario);

        return this;
    };


    //whether a given scenario is supported by the desired implementation
    automator.deviceSupportsScenario = function(scenario) {
        // if any actions are neither defined for the current device nor "default"
        for (var i = 0; i < scenario.steps.length; ++i) {
            var s = scenario.steps[i];
            // device not defined
            if (undefined === s.action.isCorrectScreen[config.implementation]) {
                UIALogger.logDebug(["Skipping scenario '", scenario.title,
                                    "' because screen '", s.action.screenName, "'",
                                    " doesn't have a screenIsActive function for ", config.implementation].join(""));
                return false;
            }

            // action not defined for device
            if (s.action.actionFn["default"] === undefined && s.action.actionFn[config.implementation] === undefined) {
                UIALogger.logDebug(["Skipping scenario '", scenario.title, "' because action '",
                                    s.action.screenName, ".", s.action.name,
                                    "' isn't suppored on ", config.implementation].join(""));
                return false;
            }
        }

        return true;
    };

    // whether a given scenario is a match for the given tags
    automator.scenarioMatchesCriteria = function(scenario, tagsAny, tagsAll, tagsNone) {
        // if any tagsAll are missing from scenario, fail
        for (var i = 0; i < tagsAll.length; ++i) {
            var t = tagsAll[i];
            if (!(t in scenario.tags_obj)) return false;
        }

        // if any tagsNone are present in scenario, fail
        for (var i = 0; i < tagsNone.length; ++i) {
            var t = tagsNone[i];
            if (t in scenario.tags_obj) return false;
        }

        // if no tagsAny specified, special case for ALL tags
        if (0 == tagsAny.length) return true;

        // if any tagsAny are present in scenario, pass
        for (var i = 0; i < tagsAny.length; ++i) {
            var t = tagsAny[i];
            if (t in scenario.tags_obj) return true;
        }

        return false; // no tags matched
    };



    // generate a readable parameter list
    automator.paramsToString = function(actionparams) {
        var param_list = [];
        for (var p in actionparams) {
            var pp = actionparams[p];
            param_list.push([p,
                             " (",
                             pp.required ? "required" : "optional",
                             ": ",
                             pp.description,
                             ")"
                             ].join(""));
        }

        return ["parameters are: [",
                param_list.join(", "),
                "]"].join("");
    };


    // add a step to the most recently created scenario
    automator.withStep = function(screenaction, testparameters) {
        // generate a helpful error message if the screen action isn't defined
        if (undefined === screenaction || typeof screenaction === 'string') {
            var failmsg = ["withStep received an undefined screen action in scenario '",
                           automator.lastScenario.title,
                           "'"
                           ];
            var slength = automator.lastScenario.steps.length;
            if (0 < slength) {
                var goodAction = automator.lastScenario.steps[slength - 1].action;
                failmsg.push(" after step " + goodAction.screenName + "." + goodAction.name);
            }
            fail(failmsg.join(""));
        }

        if (debugAutomator) {
            UIALogger.logDebug("screenaction is " + JSON.stringify(screenaction));
            UIALogger.logDebug("screenaction.params is " + JSON.stringify(screenaction.params));
        }

        // check that parameters required by the screen action are present
        for (var ap in screenaction.params) {
            if (screenaction.params[ap].required && (undefined === testparameters || undefined === testparameters[ap])) {
                failmsg = ["In scenario '",
                           automator.lastScenario.title,
                           "' in step ", automator.lastScenario.steps.length + 1,
                           " (", screenaction.name, ") ",
                           "missing required parameter '",
                           ap,
                           "'; ",
                           automator.paramsToString(screenaction.params)
                           ].join("");
                fail(failmsg);
            }
        }

        var step = {
            action: screenaction
        };

        // check that all params provided by the test are known by the action
        if (testparameters !== undefined) {

            for (var p in testparameters) {
                if (undefined === screenaction.params[p]) {
                    failmsg = ["In scenario '",
                               automator.lastScenario.title,
                               "' in step ", automator.lastScenario.steps.length + 1,
                               " (", screenaction.name, ") ",
                               "received undefined parameter '",
                               p,
                               "'; ",
                               automator.paramsToString(screenaction.params)
                               ].join("");
                    fail(failmsg);
                }
            }

            step.parameters = testparameters;
        }

        automator.lastScenario.steps.push(step);

        return this;
    };


    // log some information about the automation environment
    automator.logInfo = function () {
        UIALogger.logMessage("Device info: " +
                             "name='" + target().name() + "', " +
                             "model='" + target().model() + "', " +
                             "systemName='" + target().systemName() + "', " +
                             "systemVersion='" + target().systemVersion() + "', ");

        var tags = {};
        for (var s = 0; s < automator.allScenarios.length; ++s) {
            var scenario = automator.allScenarios[s];

            // get all tags
            for (var k in scenario.tags_obj) {
                tags[k] = 1;
            }
        }

        var tagsArr = [];
        for (var k in tags) {
            tagsArr.push(k);
        }

        UIALogger.logMessage("Defined tags: '" + tagsArr.join("', '") + "'");

    };


    /**
     * Log information about the currently-shown iOS screen
     *
     */
    automator.logScreenInfo = function () {
        //UIATarget.localTarget().logElementTree(); // ugly
        UIALogger.logDebug(target().elementReferenceDump("target()"));
        UIALogger.logDebug(target().elementReferenceDump("target()", true));
    };


    /**
     * Render the automator scenarios (and their steps, and parameters) to markdown
     *
     * @return string containing markdown
     */
    automator.toMarkdown = function () {
        var ret = ["The following scenarios are defined in the Illuminator Automator:"];

        var title = function (rank, text) {
            var total = 4;
            for (var i = 0; i <= (total - rank); ++i) {
                ret.push("");
            }

            switch (rank) {
            case 1:
                ret.push(text);
                ret.push(Array(Math.max(10, text.length) + 1).join("="));
                break;
            case 2:
                ret.push(text);
                ret.push(Array(Math.max(10, text.length) + 1).join("-"));
                break;
            default:
                ret.push(Array(rank + 1).join("#") + " " + text);
            }
        };

        title(1, "Automator Scenarios");
        // iterate over scenarios
        for (var i = 0; i < automator.allScenarios.length; ++i) {
            var scenario = automator.allScenarios[i];
            title(2, scenario.title);
            ret.push("Tags: `" + scenario.tags.join("`, `") + "`");
            ret.push("");

            // iterate over steps (actions)
            for (var j = 0; j < scenario.steps.length; ++j) {
                var step = scenario.steps[j];
                ret.push((j + 1).toString() + ". **" + step.action.screenName + "." + step.action.name + "**: " + step.action.description);

                // iterate over parameters in the action
                for (var k in step.parameters) {
                    var val = step.parameters[k];
                    var v;

                    // formatting based on datatype of parameter
                    switch ((typeof val).toString()) {
                    case "number":
                    case "boolean":
                        v = val; // no change
                        break;
                    case "function":
                    case "string":
                        v = "`" + val + "`"; // backtick-quote
                        break;
                    default:
                        v = "`" + JSON.stringify(val) + "`"; // stringify and annotate with type
                        if (val instanceof Array) {
                            v += " (Array)";
                        } else {
                            v += " (" + (typeof val) + ")";
                        }
                    }
                    ret.push("    * `" + k + "` = " + v);
                }
            }
        }
        return ret.join("\n");
    };


    /**
     * ENTRY POINT: Run tagged scenarios
     *
     * Run scenarios that match 3 sets of provided tags
     *
     * @param tagsAny array - any scenario with any matching tag will run (if tags=[], run all)
     * @param tagsAll array - any scenario with AT LEAST the same tags will run
     * @param tagsNone array - any scenario with NONE of these tags will run
     * @param randomSeed integer - if provided, will be used to randomize the run order
     */
    automator.runTaggedScenarios = function(tagsAny, tagsAll, tagsNone, randomSeed) {
        automator.checkInit();
        UIALogger.logMessage("Automator running scenarios with tagsAny: [" + tagsAny.join(", ") + "]"
                             + ", tagsAll: [" + tagsAll.join(", ") + "]"
                             + ", tagsNone: [" + tagsNone.join(", ") + "]");

        // filter the list by criteria
        var onesToRun = [];
        for (var i = 0; i < automator.allScenarios.length; ++i) {
            var scenario = automator.allScenarios[i];
            if (automator.scenarioMatchesCriteria(scenario, tagsAny, tagsAll, tagsNone)
                && automator.deviceSupportsScenario(scenario)) {
                onesToRun.push(scenario);
            }
        }

        automator.runScenarioList(onesToRun, randomSeed);
    };

    /**
     * ENTRY POINT: Run named scenarios
     *
     * Run scenarios that match the names of those provided
     *
     * @param scenarioNames array - the list of named scenarios to run
     * @param randomSeed integer - if provided, will be used to randomize the run order
     */
    automator.runNamedScenarios = function(scenarioNames, randomSeed) {
        automator.checkInit();
        UIALogger.logMessage("Automator running " + scenarioNames.length + " scenarios by name");

        // filter the list by name
        var onesToRun = [];
        for (var i = 0; i < automator.allScenarios.length; ++i) {
            var scenario = automator.allScenarios[i];
            for (var j = 0; j < scenarioNames.length; ++j) {
                if (scenario.title == scenarioNames[j] && automator.deviceSupportsScenario(scenario)) {
                    onesToRun.push(scenario);
                }
            }
        }

        automator.runScenarioList(onesToRun, randomSeed);
    };


    /**
     * run a given list of scenarios, optionally in randomized order
     *
     * @param senarioList array of scenarios to run, in order
     * @param ramdomSeed optional number, if provided the test run order will be randomized with this as a seed
     */
    automator.runScenarioList = function(scenarioList, randomSeed) {
        // randomize if asked
        if (randomSeed !== undefined) {
            UIALogger.logMessage("Automator RANDOMIZING scenarios with seed = " + randomSeed);
            onesToRun = automator.shuffle(scenarioList, randomSeed);
        }

        var hms = function(t) {
            var s = Math.floor(t);
            var h = Math.floor(s / 3600);
            s -= h * 3600;
            var m = Math.floor(s / 60);
            s -= m * 60;

            h = h > 0 ? (h + ":") : "";
            m = (m >= 10 ? m.toString() : ("0" + m)) + ":";
            s = (s >= 10 ? s.toString() : ("0" + s));
            return h + m + s;
        }

        var dt;
        var t0 = getTime();
        // iterate through scenarios and run them
        UIALogger.logMessage(scenarioList.length + " scenarios to run");
        for (var i = 0; i < scenarioList.length; i++) {
            var message = "Running scenario " + (i + 1).toString() + " of " + scenarioList.length;
            var scenario = scenarioList[i];
            var t1 = getTime();
            automator.runScenario(scenario, message);
            dt = getTime() - t1;
            UIALogger.logDebug("Scenario completed in " + hms(dt));
        }
        dt = getTime() - t0;
        UIALogger.logMessage("Automation completed in " + hms(dt));
        bridge.runNativeMethod("automationEnded:");
        return this;
    };


    /**
     * Run a single scenario and record its pass/fail status
     *
     * @param scenario an automator scenario
     * @param message string a message to print at the beginning of the test, immediately after the start
     */
    automator.runScenario = function(scenario, message) {
        automator.checkInit();
        automator._deferredFailures = []; // reset any deferred errors

        var testname = [scenario.title, " [", scenario.tags.join(", "), "]"].join("");
        UIALogger.logDebug("###############################################################");
        UIALogger.logStart(testname);
        if(undefined !== message) {
            UIALogger.logMessage(message);
        }

        // print the previous scenario in case we are running with a randomizer
        if (automator.lastRunScenario) {
            UIALogger.logMessage("(Previous test was: " + automator.lastRunScenario + ")");
        } else {
            UIALogger.logDebug("(No previous test)");
        }

        // initialize the scenario
        UIALogger.logMessage("STEP 0: Reset automator for new scenario");
        try {
            automator.resetState();
            automator.callback["prescenario"]();
        } catch (e) {
            automator.logScreenInfo();
            UIALogger.logFail("Test setup failed: " + e);
            return;
        }

        // wrap the iteration of the test steps in try/catch
        var step = null;
        try {

            // if we iterate all steps without exception, test passes
            for (var i = 0; i < scenario.steps.length; i++) {
                var step = scenario.steps[i];
                if (debugAutomator) {
                    UIALogger.logDebug("----------------------------------------------------------------");
                    UIALogger.logDebug(["STEP", i + 1, JSON.stringify(step)].join(""));
                }

                // set the current step name
                automator._state.internal["currentStepName"] = step.action.screenName + "." + step.action.name;
                automator._state.internal["currentStepNumber"] = i + 1;

                // build the parameter list to go in the step description
                var parameters = step.parameters;
                var parameters_arr = [];
                var parameters_str = "";
                for (var k in parameters) {
                    var v = parameters[k];
                    if (step.action.params[k].useInSummary && undefined !== v) {
                        parameters_arr.push(k.toString() + ": " + v.toString());
                    }
                }

                // make the descriptive parameter string
                parameters_str = parameters_arr.length ? (" {" + parameters_arr.join(", ") + "}") : "";

                // build the step description
                UIALogger.logDebug("----------------------------------------------------------------");
                UIALogger.logMessage(["STEP ", i + 1, " of ",
                                      scenario.steps.length, ": ",
                                      step.action.description,
                                      parameters_str
                                      ].join(""));

                // assert isCorrectScreen function
                if (undefined === step.action.isCorrectScreen[config.implementation]) {
                    throw ["No isCorrectScreen function defined for '",
                           step.action.screenName, ".", step.action.name,
                           "' on ", config.implementation].join("");
                }

                // assert correct screen
                if (!step.action.isCorrectScreen[config.implementation]()) {
                    throw ["Failed assertion that '", step.action.screenName, "' is active"].join("");
                }

                var actFn = step.action.actionFn["default"];
                if (step.action.actionFn[config.implementation] !== undefined) actFn = step.action.actionFn[config.implementation];

                // call step action with or without parameters, as appropriate
                if (parameters !== undefined) {
                    actFn.call(this, parameters);
                } else {
                    actFn.call(this);
                }

            }

            // check for any deferred errors
            if (0 == automator._deferredFailures.length) {
                UIALogger.logPass(testname);
            } else {
                for (var i = 0; i < automator._deferredFailures.length; ++i) {
                    UIALogger.logMessage("Deferred Failure " + (i + 1).toString() + ": " + automator._deferredFailures[i]);
                }
                UIALogger.logFail(["The test completed all its steps, but",
                                   automator._deferredFailures.length.toString(),
                                   "failures were deferred"].join(" "));
            }

        } catch (exception) {
            var failmsg = exception.message ? exception.message : exception.toString();
            var longmsg = (['Step ', i + 1, " of ", scenario.steps.length, " (",
                            step.action.screenName, ".", step.action.name,
                            ') failed in scenario: "', scenario.title,
                            '" with message: ', failmsg].join(""));

            UIALogger.logDebug("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            UIALogger.logDebug(["FAILED:", failmsg].join(" "));
            automator.logScreenInfo();
            UIATarget.localTarget().captureScreenWithName(step.name);
            UIALogger.logDebug("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            UIALogger.logDebug(longmsg);
            UIALogger.logFail(longmsg);
       }

        automator.lastRunScenario = scenario.title;
    };


    /**
     * Shuffle an array - Knuth Shuffle implementation using a PRNG
     *
     * @param array the array to be shuffled
     * @param seed number to seed the PRNG
     */
    automator.shuffle = function(array, seed) {
        var idx = array.length;
        var tmp;
        var rnd;

        // count backwards from the end of the array, swapping the current element with a random one
        while (0 !== idx) {
            // randomize BEFORE decrement because we get a modded value
            rnd = (Math.pow(2147483647, idx) + seed) % array.length; // use merseinne prime
            idx -= 1;

            // swap
            tmp = array[idx];
            array[idx] = array[rnd];
            array[rnd] = tmp;
        }

        return array;
    };

}).call(this);
