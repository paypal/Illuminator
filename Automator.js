// Automator.js
//
// creates 'automator' which can build and run scenarios

var debugAutomator = false;

(function () {

    var root = this,
        automator = null;

    // put automator in namespace of importing code
    if (typeof exports !== 'undefined') {
        automator = exports;
    } else {
        automator = root.automator = {};
    }

    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Exception classes and helpers
    //
    ////////////////////////////////////////////////////////////////////////////////////////////

    automator.ScenarioSetupException = makeErrorClassWithGlobalLocator("Automator.js", "ScenarioSetupException");


    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Callbacks for test initialization - customizing Illuminator's behavior
    //
    ////////////////////////////////////////////////////////////////////////////////////////////

    // table of callbacks that are used by automator.  sensible defaults.
    automator.callback = {
        onInit: function () { UIALogger.logDebug("Running default automator 'onInit' callback"); },
        prepare: function () { UIALogger.logDebug("Running default automator 'prepare' callback"); },
        preScenario: function (parm) { UIALogger.logDebug("Running default automator 'preScenario' callback " + JSON.stringify(parm)); },
        onScenarioPass: function (parm) { UIALogger.logDebug("Running default automator 'onScenarioPass' callback " + JSON.stringify(parm)); },
        onScenarioFail: function (parm) { UIALogger.logDebug("Running default automator 'onScenarioFail' callback " + JSON.stringify(parm)); },
        complete: function (parm) { UIALogger.logDebug("Running default automator 'complete' callback " + JSON.stringify(parm)); }
    };

    /**
     * set the callback for Automator initialization, to be called only once -- after scenarios have been added
     *
     * The callback function takes an associative array with the following keys:
     *  - entryPoint
     *
     * @param fn the callback function, taking an associative array and whose return value is ignored
     */
    automator.setCallbackOnInit = function (fn) {
        automator.callback["onInit"] = fn;
    };

    /**
     * set the callback for Automator run preparation, to be called only once -- before any scenarios execute
     *
     * This callback function will only be called if the automator's entry point requires tests to be run
     *
     * @param fn the callback function, taking no arguments and whose return value is ignored
     */
    automator.setCallbackPrepare = function (fn) {
        automator.callback["prepare"] = fn;
    };

    /**
     * set the callback function for pre-scenario initialization -- called before each scenario run
     *
     * @param fn the callback function, taking no arguments and whose return value is ignored
     */
    automator.setCallbackPreScenario = function (fn) {
        automator.callback["preScenario"] = fn;
    };

    /**
     * set the callback function for successful completion of a scenario
     *
     * The callback function takes an associative array with the following keys:
     *  - scenarioName
     *  - timeStarted
     *  - duration
     *
     * @param fn the callback function, taking an associative array and whose return value is ignored
     */
    automator.setCallbackOnScenarioPass = function (fn) {
        automator.callback["onScenarioPass"] = fn;
    };

    /**
     * set the callback function for failed completion of a scenario
     *
     * The callback function takes an associative array with the following keys:
     *  - scenarioName
     *  - timeStarted
     *  - duration
     *
     * @param fn the callback function, taking an associative array and whose return value is ignored
     */
    automator.setCallbackOnScenarioFail = function (fn) {
        automator.callback["onScenarioFail"] = fn;
    };

    /**
     * set the callback function for the conclusion of all scenarios
     *
     * The callback function takes an associative array with the following keys:
     *  - timeStarted
     *  - duration
     *
     * @param fn the callback function, taking  and whose return value is ignored
     */
    automator.setCallbackComplete = function (fn) {
        automator.callback["complete"] = fn;
    };


    /**
     * Safely execute a callback
     *
     * @param callbackName the string key into the callback array
     * @param parameters the parameter array that should be passed to the callback
     * @param doLogFail whether to log a failure message (i.e. whether we are currently in a test)
     * @param doLogScreen whether to log the screen on a failure
     * @return bool whether the callback was successful
     */
    automator._executeCallback = function (callbackName, parameters, doLogFail, doLogScreen) {
        try {
            // call with parameters if supplied and return normally
            if (parameters === undefined) {
                automator.callback[callbackName]();
            } else {
                automator.callback[callbackName](parameters);
            }
            return true;
        } catch (e) {
            var failMessage = "Callback '" + callbackName + "' failed: " + e;

            // log info as requested
            if (doLogScreen) {
                automator.logScreenInfo();
            }
            automator.logStackInfo(e);

            if (doLogFail) {
                UIALogger.logFail(failMessage);
            } else {
                UIALogger.logError(failMessage);
            }
            return false;
        }
    };


    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Functions to handle automator state -- ways for scenario steps to register side effects
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    automator._state = {};
    automator._state.external = {};

    /**
     * Reset the automator state for a new test scenario to run
     */
    automator._resetState = function () {
        automator._state.external = {};
        automator._state.internal = {"deferredFailures": []};
    };

    /**
     * Store a named state in automator
     *
     * @param key the name of the state
     * @param value the value of the state
     */
    automator.setState = function (key, value) {
        automator._state.external[key] = value;
    };

    /**
     * Predicate, whether there is a stored state for a key
     *
     * @param key the key to check
     * @return bool whether there is a state with that key
     */
    automator.hasState = function (key) {
        return undefined !== automator._state.external[key];
    };

    /**
     * Get the state with the given name.  If it doesn't exist, return the default value
     *
     * @param key the name of the state
     * @param defaultValue the value to return if key is undefined
     */
    automator.getState = function (key, defaultValue) {
        if (automator.hasState(key)) return automator._state.external[key];

        UIALogger.logDebug("Automator state '" + key + "' not found, returning default");
        return defaultValue;
    };

    /**
     * Defer a failure until the end of the test scenario
     *
     * @param err the error object
     */
    automator.deferFailure = function (err) {
        UIALogger.logDebug("Deferring an error: " + err);
        automator.logScreenInfo();
        automator.logStackInfo(getStackTrace());

        if (automator._state.internal["currentStepName"] && automator._state.internal["currentStepNumber"]) {
            var msg = "Step " + automator._state.internal["currentStepNumber"];
            msg += " (" + automator._state.internal["currentStepName"] + "): ";
            automator._state.internal.deferredFailures.push(msg + err);
        } else {
            automator._state.internal.deferredFailures.push("<Undefined step>: " + err);
        }
    };


    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Functions to build test scenarios
    //
    ////////////////////////////////////////////////////////////////////////////////////////////

    automator.allScenarios = []; // flat list of scenarios
    automator.lastScenario = null; // state variable for building scenarios of steps
    automator.allScenarioNames = {}; // for ensuring name uniqueness

    // make a lookup array of characters that aren't allowed in tags
    var disallowedTagChars = "!@#$%^&*()[]{}<>`~,'\"/\\+=;:";
    automator.disallowedTagChars = {};
    for (var i = 0; i < disallowedTagChars.length; ++i) {
        automator.disallowedTagChars[disallowedTagChars[i]] = true;
    }

    /**
     * Create an empty scenario with the given name and tags
     *
     * @param scenarioName the name for the scenario - must be unique
     * @param tags array of tags for the scenario
     * @return this
     */
    automator.createScenario = function (scenarioName, tags) {
        if (tags === undefined) tags = ["_untagged"]; // always have a tag

        // check uniqueness
        if (automator.allScenarioNames[scenarioName]) {
            throw new automator.ScenarioSetupException("Can't create Scenario '" + scenarioName + "', because that name already exists");
        }
        automator.allScenarioNames[scenarioName] = true;

        // check for disallowed characters in tag names
        for (var i = 0; i < tags.length; ++i) {
            var tag = tags[i];
            for (var j = 0; j < tag.length; ++j) {
                c = tag[j];
                if (automator.disallowedTagChars[c]) {
                    throw new automator.ScenarioSetupException("Disallowed character '" + c + "' in tag '" + tag + "' in scenario '" + scenarioName + "'");
                }
            }
        }

        // create base object
        automator.lastScenario = {
            title: scenarioName,
            steps: []
        };

        if (debugAutomator) {
            UIALogger.logDebug(["Automator creating scenario '", scenarioName, "'",
                                " [", tags.join(", "), "]",
                                ].join(""));
        }

        // add tags to objects
        automator.lastScenario.tags_obj = {}; // convert tags to object
        for (var i = 0; i < tags.length; ++i) {
            var t = tags[i];
            automator.lastScenario.tags_obj[t] = true;
        }

        // add information about where scenario was created (roughly)
        var stack = getStackTrace();
        for (var i = 0; i < stack.length; ++i) {
            var l = stack[i];
            if (!(l.nativeCode || l.file == "Automator.js")) {
                automator.lastScenario.inFile = l.file;
                automator.lastScenario.definedBy = l.functionName;
                break;
            }
        }


        // add new scenario to list
        automator.allScenarios.push(automator.lastScenario);

        return this;
    };


    /**
     * Throw an exception if any parameters required for the screen action are not supplied
     *
     * @param screenAction an AppMap screen action
     * @param suppliedParameters associative array of parameters
     */
    automator._assertAllRequiredParameters = function (screenAction, suppliedParameters) {
        for (var ap in screenAction.params) {
            if (screenAction.params[ap].required && (undefined === suppliedParameters || undefined === suppliedParameters[ap])) {
                failmsg = ["In scenario '",
                           automator.lastScenario.title,
                           "' in step ", automator.lastScenario.steps.length + 1,
                           " (", screenAction.name, ") ",
                           "missing required parameter '",
                           ap,
                           "'; ",
                           automator.paramsToString(screenAction.params)
                          ].join("");
                throw new automator.ScenarioSetupException(failmsg);
            }
        }
    };


    /**
     * Throw an exception if any parameters supplied to the screen action are unrecognized
     *
     * @param screenAction an AppMap screen action
     * @param suppliedParameters associative array of parameters
     */
    automator._assertAllKnownParameters = function (screenAction, suppliedParameters) {
        for (var p in suppliedParameters) {
            if (undefined === screenAction.params[p]) {
                failmsg = ["In scenario '",
                           automator.lastScenario.title,
                           "' in step ", automator.lastScenario.steps.length + 1,
                           " (", screenAction.name, ") ",
                           "received undefined parameter '",
                           p,
                           "'; ",
                           automator.paramsToString(screenAction.params)
                          ].join("");
                throw new automator.ScenarioSetupException(failmsg);
            }
        }
    };


    /**
     * Add a step to the most recently created scenario
     *
     * @param screenAction an AppMap screen action
     * @param desiredParameters associative array of parameters
     * @return this
     */
    automator.withStep = function (screenAction, desiredParameters) {
        // generate a helpful error message if the screen action isn't defined
        if (undefined === screenAction || typeof screenAction === 'string') {
            var failmsg = ["withStep received an undefined screen action in scenario '",
                           automator.lastScenario.title,
                           "'"
                           ];
            var slength = automator.lastScenario.steps.length;
            if (0 < slength) {
                var goodAction = automator.lastScenario.steps[slength - 1].action;
                failmsg.push(" after step " + goodAction.screenName + "." + goodAction.name);
            }
            throw new automator.ScenarioSetupException(failmsg.join(""));
        }

        // debug if necessary
        if (debugAutomator) {
            UIALogger.logDebug("screenAction is " + JSON.stringify(screenAction));
            UIALogger.logDebug("screenAction.params is " + JSON.stringify(screenAction.params));
        }

        // create a step and check parameters
        var step = {action: screenAction};
        automator._assertAllRequiredParameters(screenAction, desiredParameters);
        if (desiredParameters !== undefined) {
            automator._assertAllKnownParameters(screenAction, desiredParameters);
            step.parameters = desiredParameters;
        }

        // add step to scenario
        automator.lastScenario.steps.push(step);
        return this;
    };


    /**
     * Add steps to the most recently created scenario by running a function that creates them
     *
     * @param stepGeneratorFn the function that will generate the steps
     * @param desiredParameters associative array of parameters
     * @return this
     */
    automator.withGeneratedSteps = function(stepGeneratorFn, desiredParameters) {
        stepGeneratorFn(desiredParameters);
        return this;
    };

    /**
     * Add a step to the most recently created scenario if the given condition is true at scenario creation time
     *
     * @param screenAction an AppMap screen action
     * @param desiredParameters associative array of parameters
     * @return this
     */
    automator.withConditionalStep = function(condition, screenAction, desiredParameters) {
        if(condition){
            automator.withStep(screenAction, desiredParameters)
        }
        return this;
    };

    /**
     * Add a repeated step to the most recently created scenario
     *
     * @param screenAction an AppMap screen action
     * @param quantity the number of times that the step should be executed
     * @param desiredParameters associative array of parameters, or a function taking 0-indexed run number that returns parameters
     * @return this
     */
    automator.withRepeatedStep = function(screenAction, quantity, desiredParameters) {
        var mkParm;

        // use the function they made, or make a function that returns the params they supplied
        if ((typeof desiredParameters) == "function") {
            mkParm = desiredParameters;
        } else {
            mkParm = function (_) {
                return desiredParameters;
            };
        }

        for (var i = 0; i < quantity; ++i) {
            automator.withStep(screenAction, mkParm(i));
        }
        return this;
    };



    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Functions to run test scenarios
    //
    ////////////////////////////////////////////////////////////////////////////////////////////


    automator.lastRunScenario = null;

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
    automator.runTaggedScenarios = function (tagsAny, tagsAll, tagsNone, randomSeed) {
        UIALogger.logMessage("Automator running scenarios with tagsAny: [" + tagsAny.join(", ") + "]"
                             + ", tagsAll: [" + tagsAll.join(", ") + "]"
                             + ", tagsNone: [" + tagsNone.join(", ") + "]");

        // filter the list by criteria
        var onesToRun = [];
        for (var i = 0; i < automator.allScenarios.length; ++i) {
            var scenario = automator.allScenarios[i];
            if (automator.scenarioMatchesCriteria(scenario, tagsAny, tagsAll, tagsNone)
                && automator.targetSupportsScenario(scenario)) {
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
    automator.runNamedScenarios = function (scenarioNames, randomSeed) {
        UIALogger.logMessage("Automator running " + scenarioNames.length + " scenarios by name");

        // filter the list by name
        var onesToRun = [];
        // consider the full list of scenarios
        for (var i = 0; i < automator.allScenarios.length; ++i) {
            var scenario = automator.allScenarios[i];
            // check whether any of the given scenario names match the scenario in the master list
            for (var j = 0; j < scenarioNames.length; ++j) {
                if (scenario.title == scenarioNames[j] && automator.targetSupportsScenario(scenario)) {
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
    automator.runScenarioList = function (scenarioList, randomSeed) {
        // randomize if asked
        if (randomSeed !== undefined) {
            UIALogger.logMessage("Automator RANDOMIZING scenarios with seed = " + randomSeed);
            onesToRun = automator.shuffle(scenarioList, randomSeed);
        }

        // run initial callback and only continue on if it succeeds
        if (!automator._executeCallback("prepare", undefined, false, false)) return;

        // At this point, we consider the instruments/app launch to be a success
        // this function will also serve as notification to the framework that we consider instruments to have started
        automator.saveIntendedTestList(scenarioList);

        var dt;
        var t0 = getTime();
        // iterate through scenarios and run them
        UIALogger.logMessage(scenarioList.length + " scenarios to run");
        for (var i = 0; i < scenarioList.length; i++) {
            var message = "Running scenario " + (i + 1).toString() + " of " + scenarioList.length;
            automator.runScenario(scenarioList[i], message);
        }
        dt = getTime() - t0;
        UIALogger.logMessage("Completed running scenario list (" + scenarioList.length + " scenarios) in " + secondsToHMS(dt));

        // create a CSV report for the amount of time spent evaluating selectors
        automator.saveSelectorReportCSV("selectorTimeCostReport");

        // run completion callback
        var info = {
            scenarioCount: scenarioList.length,
            timeStarted: t0,
            duration: dt
        };
        automator._executeCallback("complete", info, false, false);

        return this;
    };


    /**
     * Save a JSON structure indicating the list of tests that will be run
     *
     * @param scenarioList an array of scenario objects
     */
    automator.saveIntendedTestList = function (scenarioList) {
        var names = [];
        for (var i = 0; i < scenarioList.length; ++i) {
            names.push(scenarioList[i].title);
        }

        var intendedListPath = config.buildArtifacts.intendedTestList;
        if (!writeToFile(intendedListPath, JSON.stringify({scenarioNames: names}, null, "    "))) {
            throw new IlluminatorRuntimeFailureException("Could not save intended test list to " + intendedListPath);
        }

        notifyIlluminatorFramework("Saved intended test list to: " + intendedListPath);
    };

    /**
     * Save a report to disk of the amount of time evaluating selectors (CSV)
     *
     * @param selectorReport the value of extensionProfiler.getCriteriaCost()
     * @param reportName the basename of the report -- no path, no .csv extension
     */
    automator.saveSelectorReportCSV = function (reportName) {
        var totalSelectorTime = 0;
        var selectorReportCsvPath = config.buildArtifacts.root + "/" + reportName + ".csv";
        var csvLines = ["\"Total time (seconds)\",Count,\"Average time\",Selector"];
        var selectorReport = extensionProfiler.getCriteriaCost();
        for (var i = 0; i < selectorReport.length; ++i) {
            var rec = selectorReport[i];
            totalSelectorTime += rec.time;
            csvLines.push(rec.time.toString() + "," + rec.hits + "," + (rec.time / rec.hits) + ",\"" + rec.criteria.replace(/"/g, '""') + '"');
        }
        if (writeToFile(selectorReportCsvPath, csvLines.join("\n"))) {
            UIALogger.logMessage("Overall time spent evaluating soft selectors: " + secondsToHMS(totalSelectorTime)
                                 + " - full report at " + selectorReportCsvPath);
        }
    };

    /**
     * Run a single scenario and handle all its reporting callbacks
     *
     * @param scenario an automator scenario
     * @param message string a message to print at the beginning of the test, immediately after the start
     */
    automator.runScenario = function (scenario, message) {
        var t1 = getTime();
        var passed = automator._evaluateScenario(scenario, message);
        var dt = getTime() - t1;
        var info = {
            scenarioName: scenario.title,
            timeStarted: t1,
            duration: dt
        };

        UIALogger.logDebug("Scenario completed in " + secondsToHMS(dt));
        automator._executeCallback(passed ? "onScenarioPass" : "onScenarioFail", info, false, false);
    };


    /**
     * Describe a scenario step (to the log)
     *
     * @param stepNumber the 1-indexed number of this step in the scenario
     * @param totalSteps the total number of steps in this scenario
     * @param step an automator scenario step
     */
    automator._logScenarioStep = function (stepNumber, totalSteps, step) {
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
        UIALogger.logMessage(["STEP ", stepNumber, " of ", totalSteps, ": ",
                              "(", step.action.appName, ".", step.action.screenName, ".", step.action.name, ") ",
                              step.action.description,
                              parameters_str
                             ].join(""));
    };


    /**
     * Assert that an automator step is on the correct screen
     *
     * @param step an automator scenario step
     */
    automator._assertCorrectScreen = function (step) {
        // assert isCorrectScreen function exists
        if (undefined === step.action.isCorrectScreen[config.implementation]) {
            throw new IlluminatorSetupException(["No isCorrectScreen function defined for '",
                                                 step.action.screenName, ".", step.action.name,
                                                 "' on ", config.implementation].join(""));
        }

        // assert correct screen
        if (!step.action.isCorrectScreen[config.implementation]()) {
            throw new IlluminatorRuntimeVerificationException(["Failed assertion that '", step.action.screenName, "' is active"].join(""));
        }
    };


    /**
     * Extract the implementation-specific action from a step and execute it
     *
     * @param step an automator scenario step
     */
    automator._executeStepAction = function (step) {
        var actFn = step.action.actionFn["default"];
        if (step.action.actionFn[config.implementation] !== undefined) actFn = step.action.actionFn[config.implementation];

        // call step action with or without parameters, as appropriate
        if (step.parameters !== undefined) {
            actFn.call(this, step.parameters);
        } else {
            actFn.call(this);
        }
    };


    /**
     * Run a single scenario and return its pass/fail status
     *
     * @param scenario an automator scenario
     * @param message string a message to print at the beginning of the test, immediately after the start
     * @return boolean whether the scenario finished successfully
     */
    automator._evaluateScenario = function (scenario, message) {

        var testname = scenario.title;
        UIALogger.logDebug("###############################################################");
        UIALogger.logStart(testname);
        UIALogger.logMessage(["Scenario tags are [", Object.keys(scenario.tags_obj).join(", "), "]"].join(""));
        if (undefined !== message) {
            UIALogger.logMessage(message);
        }

        // print the previous scenario in case we are running with a randomizer
        if (automator.lastRunScenario) {
            UIALogger.logMessage("(Previous test was: " + automator.lastRunScenario + ")");
        } else {
            UIALogger.logDebug("(No previous test)");
        }
        automator.lastRunScenario = scenario.title;

        // initialize the scenario
        UIALogger.logDebug("----------------------------------------------------------------");
        UIALogger.logMessage("STEP 0: Reset automator for new scenario");
        automator._resetState();
        if (!automator._executeCallback("preScenario", {scenarioName: scenario.title}, true, true)) return false;

        // wrap the iteration of the test steps in try/catch
        var step = null;
        try {

            // if we iterate all steps without exception, test passes
            for (var i = 0; i < scenario.steps.length; i++) {
                var step = scenario.steps[i];
                if (debugAutomator) {
                    UIALogger.logDebug(["DEBUG step ", i + 1, JSON.stringify(step)].join(""));
                }

                // set the current step name
                automator._state.internal["currentStepName"] = step.action.screenName + "." + step.action.name;
                automator._state.internal["currentStepNumber"] = i + 1;

                // log this step to the console
                UIALogger.logDebug("----------------------------------------------------------------");
                automator._logScenarioStep(i + 1, scenario.steps.length, step);

                // make sure the screen containing the action is active
                automator._assertCorrectScreen(step);

                // retrieve and execute the correct step action
                automator._executeStepAction(step);

            }

            // check for any deferred errors
            if (0 < automator._state.internal.deferredFailures.length) {
                for (var i = 0; i < automator._state.internal.deferredFailures.length; ++i) {
                    UIALogger.logMessage("Deferred Failure " + (i + 1).toString() + ": " + automator._state.internal.deferredFailures[i]);
                }
                UIALogger.logFail(["The test completed all its steps, but",
                                   automator._state.internal.deferredFailures.length.toString(),
                                   "failures were deferred"].join(" "));
                return false;
            }

        } catch (exception) {
            var failmsg = exception.message ? exception.message : exception.toString();
            var longmsg = (['Step ', i + 1, " of ", scenario.steps.length, " (",
                            step.action.screenName, ".", step.action.name,
                            ') failed in scenario: "', scenario.title,
                            '" with message: ', failmsg].join(""));

            UIALogger.logDebug("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            UIALogger.logDebug(["FAILED:", failmsg].join(" "));
            notifyIlluminatorFramework("Stack trace follows:");
            automator.logScreenInfo();
            automator.logStackInfo(exception);
            UIATarget.localTarget().captureScreenWithName(step.name);
            UIALogger.logDebug("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

            // check for any deferred errors
            if (0 < automator._state.internal.deferredFailures.length) {
                for (var i = 0; i < automator._state.internal.deferredFailures.length; ++i) {
                    UIALogger.logMessage("Deferred Failure " + (i + 1).toString() + ": " + automator._state.internal.deferredFailures[i]);
                }

                longmsg += [" ::", automator._state.internal.deferredFailures.length.toString(),
                            "other failures had been deferred"].join(" ");
            }
            UIALogger.logDebug(longmsg);
            UIALogger.logFail(longmsg);
            return false;
       }

        UIALogger.logPass(testname);
        return true;
    };


    /**
     * whether a given scenario is supported by the desired target implementation
     *
     * @param scenario an automator scenario
     * @return bool
     */
    automator.targetSupportsScenario = function (scenario) {
        // if any actions are neither defined for the current target nor "default"
        for (var i = 0; i < scenario.steps.length; ++i) {
            var s = scenario.steps[i];
            // target not defined
            if (undefined === s.action.isCorrectScreen[config.implementation]) {
                UIALogger.logDebug(["Skipping scenario '", scenario.title,
                                    "' because screen '", s.action.screenName, "'",
                                    " doesn't have a screenIsActive function for ", config.implementation].join(""));
                return false;
            }

            // action not defined for target
            if (s.action.actionFn["default"] === undefined && s.action.actionFn[config.implementation] === undefined) {
                UIALogger.logDebug(["Skipping scenario '", scenario.title, "' because action '",
                                    s.action.screenName, ".", s.action.name,
                                    "' isn't suppored on ", config.implementation].join(""));
                return false;
            }
        }

        return true;
    };


    /**
     * Whether a given scenario is a match for the given tags
     *
     * @param scenario an automator scenario
     * @param tagsAny array - any scenario with any matching tag will run (if tags=[], run all)
     * @param tagsAll array - any scenario with AT LEAST the same tags will run
     * @param tagsNone array - any scenario with NONE of these tags will run
     * @return bool
     */
    automator.scenarioMatchesCriteria = function (scenario, tagsAny, tagsAll, tagsNone) {
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


    /**
     * Shuffle an array - Knuth Shuffle implementation using a PRNG
     *
     * @param array the array to be shuffled
     * @param seed number to seed the PRNG
     */
    automator.shuffle = function (array, seed) {
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


    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Functions to describe the Automator
    //
    ////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * generate a readable description of the parameters that an action expects
     *
     * @param actionParams an associative array of parameters that an action defines
     * @return string
     */
    automator.paramsToString = function (actionParams) {
        var param_list = [];
        for (var p in actionParams) {
            var pp = actionParams[p];
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


    /**
     * log some information about the automation environment
     */
    automator.logInfo = function () {
        UIALogger.logMessage("Target info: " +
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
     * Log information about the current stack
     *
     * @param mixed either an error object or a stack array
     */
    automator.logStackInfo = function (mixed) {
        var stack;

        if (mixed instanceof Array) {
            stack = mixed;
        } else {
            var decoded = decodeStackTrace(mixed);

            if (!decoded.isOK) {
                UIALogger.logMessage("Decoding stack trace didn't work: " + decoded.message);
            } else {
                UIALogger.logMessage("Stack trace from " + decoded.errorName + ":");
            }
            stack = decoded.stack;
        }

        for (var i = 0; i < stack.length; ++i) {
            var l = stack[i];
            var position = "   #" + i + ": ";
            var funcName = l.functionName === undefined ? "(anonymous)" : l.functionName;
            if (l.nativeCode) {
                UIALogger.logMessage(position + funcName + " from native code");
            } else {
                UIALogger.logMessage(position + funcName + " at " + l.file + " line " + l.line + " col " + l.column);
            }
        }
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
            ret.push("Tags: `" + Object.keys(scenario.tags_obj).join("`, `") + "`");
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
                        v = "\n\n```javascript\n" + val + "\n```";
                        break;
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
     * Render the automator scenarios (tags and steps) to a javascript object
     *
     * @param includeSteps whether to include the list of test steps in the output
     * @return object
     */
    automator.toScenarioObject = function (includeSteps) {
        var ret = {scenarios: []};

        // iterate over scenarios
        for (var i = 0; i < automator.allScenarios.length; ++i) {
            var scenario = automator.allScenarios[i];
            var outScenario = {
                title: scenario.title,
                tags: Object.keys(scenario.tags_obj),
                inFile: scenario.inFile,
                definedBy: scenario.definedBy,
            };

            if (includeSteps) {
                outScenario.steps = [];

                // iterate over steps (actions)
                for (var j = 0; j < scenario.steps.length; ++j) {
                    var step = scenario.steps[j];
                    outScenario.steps.push(step.action.screenName + "." + step.action.name);
                }
            }
            ret.scenarios.push(outScenario);
        }

        return ret;
    };


}).call(this);
