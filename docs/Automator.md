Automator.js Reference
======================

Illuminator's main engine is the Automator.  The automator is the repository of all the test scenarios (sequences of [AppMap](AppMap.md) actions and their parameters) that can be used to test an app.  In addition, the Automator provides capabilities for sharing state between actions and customizing the automation environment for your application.

The Automator is a singleton object called `automator`.

Building Scenarios in the Automator
-----------------------------------

The overview of building test scenarios in the Automator is as follows:

1. Define a **scenario** by **name**, with a set of **tag**s
2. Add one or more **step**s, which are [AppMap action](AppMap.md)s plus a set of **parameter**s.

For an example of this, see the [Quick Start guide](README.md).

Note:
> Since actions are only valid from their host screen, a validation function (the screen's `verifyIsActive`) is asserted prior to each action.  `verifyIsAcive` makes a good final step in a test scenario; it asserts that the proper screen was reached, without taking further action.

Methods for building scenarios -- most meant to be chained together -- are as follows:

#### `.createScenario(scenarioName, tags)`
Create a scenario with the given `scenarioName` and `tags` array.  The `scenarioName` must be unique.  Returns a reference to the Automator

#### `.withStep(screenAction, desiredParameters)`
Add a step to the most recently-created scenario, which will execute the `screenAction` as defined in the AppMap, with an associative array of `desiredParameters` that will be passed to that action.  Returns a reference to the Automator.

Saving State Information in Automator
------------------------------------

In many cases, it is necessary to share data between AppMap actions.  For example:

* some non-deterministic token might be produced at runtime in one action, to be used at some later point by another action
* an OS-level popup (such as for location access) may need to be handled once and only once in a scenario, even if the same location access event is triggered at multiple points
* settings that come from a server may dictate expected values (like locale-specific currency)

Methods for reading and writing states (intended for use inside AppMap implementation functions) are as follows:


#### `.setState(key, value)`
Stores the state `value` under the key `key` until the next scenario runs.

#### `.hasState(key)`
Returns true when there is a stored state called `key`.

#### `.getState(key, defaultValue)`
Returns the value of the state called `key`, or `defaultValue` if there is no stored value.

#### `.deferError(errorObject)`
Some verification failures do not affect the continuation of a test scenario.  Rather than throw an error, that error can be deferred until the end of the scenario.  The scenario can then fail with the list of deferred errors.



Customizing The Automator Environment For Your App
--------------------------------------------------

Automator provides two callbacks to enable the initialization of the test environment: one for initial setup, and one that runs before each scenario.

They can be set as follows.


#### `.setCallbackOnInit(callbackFn)`
Store `callbackFn`, running it only once -- after the initialization of all automator scenarios, but before any of them will execute.  `callbackFn` will be called with a single argument (an associative array described below), and its return value will be ignored.

* `entryPoint` - the Illuminator entry point


#### `.setCallbackPrepare(callbackFn)`
Store `callbackFn`, running it only once -- before any test scenarios run -- if test scenarios are going to be run.  `callbackFn` will be called with no arguments, and its return value will be ignored.

#### `.setCallbackPreScenario(callbackFn)`
Store `callbackFn`, running it before each test scenario.  `callbackFn` will be called with a single argument (an associative array described below), and its return value will be ignored.

* `scenarioName` - the name of the scenario about to run


#### `.setCallbackOnScenarioPass(callbackFn)`
Store `callbackFn`, running it upon each successful completion of a test scenario.  `callbackFn` will be called with a single argument (an associative array described below), and its return value will be ignored.

* `scenarioName` - the name of the scenario that has completed
* `timeStarted` - epochal time that the scenario began
* `duration` - the number of seconds requried to run the scenario to successful completion


#### `.setCallbackOnScenarioFail(callbackFn)`
Store `callbackFn`, running it upon each failure of a test scenario.  `callbackFn` will be called with a single argument (an associative array described below), and its return value will be ignored.

* `scenarioName` - the name of the scenario that has completed
* `timeStarted` - epochal time that the scenario began
* `duration` - the number of seconds requried to run the scenario until its failure


#### `.setCallbackComplete(callbackFn)`
Store `callbackFn`, running it upon completion of all test scenarios.  `callbackFn` will be called with a single argument (an associative array described below), and its return value will be ignored.

* `scenarioCount` - the number of scenarios that were run
* `timeStarted` - epochal time that the scenario began
* `duration` - the number of seconds requried to run the scenario until its failure



Running Scenarios With Automator
--------------------------------

The following entry points into Automator are defined.  These are listed here for reference; ordinarily, they are initiated by the [command line](Commandline.md) scripts.

Note
> AppMap defines specific targets for its screens and actions.  If any action in a scenario is not supported by the currently-running target, **Automator will skip the scenario -- the scenario will not attempt to run** and a notification of this will be logged to the console.


#### `.runTaggedScenarios(tagsAny, tagsAll, tagsNone, randomSeed)`
Run any scenarios that correspond to the 3 sets of tags that are provided:

* `tagsAny`: If a scenario is tagged with *any* of the tags in this array, it can run.  However:
* `tagsAll`: If a scenario is *not* tagged with *all* the tags in this array, it will *not* run
* `tagsNone`: If a scenario is tagged with *any* of the tags in this array, it will *not* run

The run order will be the order in which the test scenarios are defined in code.  If the integer `randomSeed` is provided, the run order will be shuffled using the Knuth algorithm.


#### `.runNamedScenarios(scenarioNames, randomSeed)`
Run the list of scenarios named by `scenarioNames`.  If the integer `randomSeed` is provided, the run order will be shuffled using the Knuth algorithm.





Automator Method Reference - Other Methods
-------------------------------------------

#### `.targetSupportsScenario(scenario)`
Returns true if all steps in the `scenario` are supported by the defined automation target.


#### `.toMarkdown()`
Returns a string containing a markdown description of all the scenarios, steps, and their parameters in the Automator.

#### `.toScenarioObject()`
Returns an object containing an array of scenario objects, each containing a string `title`, a `tags` array, and a `steps` array.
