A Practical Introduction to iOS Automation with Illuminator
===========================================================

For [this author](http://github.com/ifreecarve/), the [technical documentation](./) can only go so far toward explaining how to use any new system, and more practical guide is more valuable.  This is that guide.

At this point, you should have taken care of the basics:

1. Downloaded the repository, or otherwise placed Illuminator on your machine
2. Run `bundle install` to bring in the appropriate Ruby gems

Let's bootstrap a project -- the Illuminator sample app.


Important Questions To Ask
--------------------------

Since we plan on running more than one automated test in a row against the app, we need a way to return the app to a known state -- no matter what!  One of the simplest ways to do this is to simply connect a reset function to an action that is available on all the screens (like the shake gesture).  At PayPal, we use a [bridge call](Bridge.md) named `resetToLogin:`.  The included sample app uses a bridge call named `returnToMainMenu:`.  Any action that can be invoked from any app state is acceptable, and must be tied to application code that returns the app to a known state.  **How will you implement this in your app?**

Since different devices can cause subtle changes in the behavior of any app, it may be necessary to perform the same action in slightly different ways.  Alternatively, two separate compilation targets (iPhone and iPad) may produce 2 separate apps but share a large amount of code -- allowing a large amount of shared automation code.  At PayPal, these translate into the automation target implementations `iPhone` and `iPad`.  These labels are completely arbitrary; they are functionally unrelated to the device names.  They could just as well be called `phone` and `tablet`, or be split into more functional variants like `short iPhone`, `tall iPhone`, `tablet`, and `phablet`.  **How many screen-specific variants of your app did you write?**


Laying Out the Basic Structure
------------------------------

The recommended filesystem structure for an Illuminator-powered automation project is as follows.  We assume that at least one bridge call will be used (`returnToMainMenu:`), and that there is only one target, called `iPhone`.

```
./MyApp/IlluminatorTests/
├── Common.js                   # App-specific automation convenience functions go here
├── screens
│   ├── AllScreens.js           # Imports all the files that define app screens
│   ├── Bridge.js               # Wrappers for bridge calls
│   └── Home.js                 # The definition of a single app screen
└── tests
    ├── AllTests.js             # Imports all the files that define app tests, and sets test callbacks
    └── FunctionalTests.js      # A set of app tests for a single functional area
```

### `Common.js`

Tis file needs no text whatsoever when you start out.  Common functions will eventually end up here.

### `AllScreens.js`

In this initial stage, this file will be a simple list of `#import` statements, one for each screen definition in  your app:

```javascript
#import "Home.js";
```


### `Home.js`

This file should be named appropriately for whatever the landing screen of your app might be, and chould contain this bare minimum implementation, to start:

```javascript
#import "../Common.js";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
appmap.createOrAugmentApp("SampleApp").withScreen("homeScreen")
    .onTarget("iPhone", function() { return false; });  // in other words, pretend the screen is never active
                                                        // this will cause an error, which will help us get started

```


### `Bridge.js`

Here is a perfectly acceptable implementation of a bridge "screen" for a single call (`resetToHomeScreen:`).  This can be seen as something of a hack, since the bridge never really appears on a screen.  But's a perfectly acceptable hack!  It helps us script bridge actions in the same format as actions for other screens.

```javascript
#import "../Common.js";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
var ab = appmap.actionBuilder.makeAction;
appmap.createOrAugmentApp("SampleApp").withScreen("bridge")
    .onTarget("iPhone", function () { return true; }) // the bridge "screen" is always active -- it is unconditionally accessible

    .withAction("resetToHomeScreen", "forcibly return the app to the home screen in an initial state")
    .withImplementation(bridge.makeActionFunction("returnToMainMenu:"));       // we changed the name on purpose so you can see how it works
```


### `AllTests.js`

Like `AllScreens.js`, this file should import all the other files that contain test definitions.  **This will be considered the top-level javascript file that we later pass to the Illuminator command line script.**  Additionally, it's a good place to place the top-level callback functions that help you better integrate with the test environment.  For illustrative purposes, we'll just print to the console when these events are triggered.

For the pre-scenario callback, we are going to run the bridge call that returns our app to its default state.

```javascript
#import "../Common.js";
#import "../screens/AllScreens.js";
#import "FunctionalTests.js";

function printCallbackArgs(sourceName) {
    return function(parm) {
        UIALogger.logDebug(sourceName + " callback firing with args: " + JSON.stringify(parm));
    };
}

automator.setCallbackPreScenario(function (parameters) {
    bridge.runNativeMethod("returnToMainMenu");
});

// for informational purposes, we'll just print out the parameters that each callback receives
automator.setCallbackOnInit(printCallbackArgs("onInit"));
automator.setCallbackPrepare(printCallbackArgs("prepare"));
automator.setCallbackOnScenarioPass(printCallbackArgs("onScenarioPass"));
automator.setCallbackOnScenarioFail(printCallbackArgs("onScenarioFail"));
automator.setCallbackComplete(printCallbackArgs("complete"));

```


### `FunctionalTests.js`

In this file, we'll lay out the very first test -- one which we already know will fail.  That's OK; the errors will help us build out the rest of our automation.

```javascript
#import "../Common.js";

var ia = appmap.apps["Illuminator"];  // shortcut reference to built-in Illuminator test steps
var app = appmap.apps["SampleApp"];   // shortcut reference to sample app test steps

automator.createScenario("The most basic of all tests", ["functional"])
    .withStep(app.homeScreen.verifyIsActive);
```

We've created the `SampleApp` and its `homeScreen` via the `appMap` back in the `Home.js` file.  But where did `.verifyIsActive` come from?  That's one of two built-in actions that come with all Illuminator screens (the other being `.verifyNotActive`, which does the reverse).  This test simply checks whether the home screen appeared after being reset.


Gearing Up To Fail Our Very First Test, And Making It Fail Even Faster
----------------------------------------------------------------------

If you were hoping to never fail a test, now is the time when you should go outside and take a few deep breaths.  We are going to generate a lot of failures as we go.

We'll start by running the test we just wrote:

```
$ ruby scripts/automationTests.rb --scheme AutomatorSampleApp --appName AutomatorSampleApp --entryPoint runTestsByTag --tags-all functional --implementation iPhone --verbose --simDevice "iPhone 5" --simVersion "7.1"

        [ build messages removed ]


Waiting for device to boot...
2015-03-31 12:29:48.039 ScriptAgent[47006:3007] CLTilesManagerClient: initialize, sSharedTilesManagerClient
2015-03-31 12:29:48.039 ScriptAgent[47006:3007] CLTilesManagerClient: init
2015-03-31 12:29:48.039 ScriptAgent[47006:3007] CLTilesManagerClient: reconnecting, 0xa044970
2015-03-31 16:29:51 +0000 Debug: Writing 249 bytes to /Users/iakatz/Code Base/ios-here-newgen/libs/ios-automator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/automatorScenarios.json as 332 bytes of b64
2015-03-31 16:29:52 +0000 Debug: 0f546f5f1ded23e12411b225896c627858b81d6b Saved scenario definitions to: /Users/iakatz/Code Base/Illuminator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/automatorScenarios.json 0f546f5f1ded23e12411b225896c627858b81d6b
2015-03-31 16:29:52 +0000 Debug: onInit callback firing with args: {"entryPoint":"runTestsByTag"}
2015-03-31 16:29:52 +0000 Default: Automator running scenarios with tagsAny: [], tagsAll: [functional], tagsNone: []
2015-03-31 16:29:52 +0000 Debug: prepare callback firing with args: undefined
2015-03-31 16:29:52 +0000 Debug: Writing 70 bytes to /Users/iakatz/Code Base/Illuminator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/intendedTestList.json as 96 bytes of b64
2015-03-31 16:29:53 +0000 Debug: 0f546f5f1ded23e12411b225896c627858b81d6b Saved intended test list to:/Users/iakatz/Code Base/Illuminator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/intendedTestList.json 0f546f5f1ded23e12411b225896c627858b81d6b
2015-03-31 16:29:53 +0000 Default: 1 scenarios to run
2015-03-31 16:29:53 +0000 Debug: ###############################################################
2015-03-31 16:29:53 +0000 Start: The most basic of all tests
2015-03-31 16:29:53 +0000 Default: Scenario tags are [functional]
2015-03-31 16:29:53 +0000 Default: Running scenario 1 of 1
2015-03-31 16:29:53 +0000 Debug: (No previous test)
2015-03-31 16:29:53 +0000 Debug: ----------------------------------------------------------------
2015-03-31 16:29:53 +0000 Default: STEP 0: Reset automator for new scenario
2015-03-31 16:29:53 +0000 Debug: Bridge running native method via 'Bridge_call_1': selector='returnToMainMenu', arguments=''
2015-03-31 16:29:53 +0000 Debug: Bridge waiting for acknowledgment of UID 'Bridge_call_1' from $ /usr/bin/ruby /Users/iakatz/Code Base/Illuminator/scripts/UIAutomationBridge.rb --callUID=Bridge_call_1 --selector=returnToMainMenu
2015-03-31 16:29:54 +0000 Debug: ----------------------------------------------------------------
2015-03-31 16:29:54 +0000 Default: STEP 1 of 1: (SampleApp.homeScreen.verifyIsActive) Null op to verify that the homeScreen screen is active
2015-03-31 16:29:54 +0000 Debug: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
2015-03-31 16:29:54 +0000 Debug: FAILED: Failed assertion that 'homeScreen' is active
2015-03-31 16:29:54 +0000 Debug: 0f546f5f1ded23e12411b225896c627858b81d6b Stack trace follows: 0f546f5f1ded23e12411b225896c627858b81d6b
2015-03-31 16:29:54 +0000 Debug: _reduce operation on [object UIATarget] completed in 0.2 seconds
2015-03-31 16:29:54 +0000 Debug: elementReferenceDump of target():
target()
target().frontMostApp()
mainWindow()
mainWindow().navigationBars()["Illuminator Sample"]
mainWindow().navigationBars()["Illuminator Sample"].buttons()["Back"]
mainWindow().navigationBars()["Illuminator Sample"].images()[0]
mainWindow().navigationBars()["Illuminator Sample"].images()[0].images()[0]
mainWindow().navigationBars()["Illuminator Sample"].staticTexts()["Illuminator Sample"]
mainWindow().tableViews()["Main Menu"]
mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"]
mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"].staticTexts()["Searching Elements"]
mainWindow().tableViews()["Main Menu"].cells()["Wait For Me"]
mainWindow().tableViews()["Main Menu"].cells()["Wait For Me"].staticTexts()["Wait For Me"]
mainWindow().tableViews()["Main Menu"].cells()["Crash The App"]
mainWindow().tableViews()["Main Menu"].cells()["Crash The App"].staticTexts()["Crash The App"]
mainWindow().tableViews()["Main Menu"].cells()["Custom Keyboard"]
mainWindow().tableViews()["Main Menu"].cells()["Custom Keyboard"].staticTexts()["Custom Keyboard"]
mainWindow().toolbars()[0]
mainWindow().toolbars()[0].images()[0]
mainWindow().toolbars()[0].images()[1]
target().frontMostApp().windows()[1]
target().frontMostApp().windows()[1].elements()[0]
target().frontMostApp().windows()[1].elements()[0].elements()["Swipe down with three fingers to reveal the notification center., Swipe up with three fingers to reveal the control center, Double-tap to scroll to top"]
target().frontMostApp().windows()[1].elements()[0].elements()["3 of 3 Wi-Fi bars"]
target().frontMostApp().windows()[1].elements()[0].elements()["12:29 PM"]
target().frontMostApp().windows()[1].elements()[0].elements()["100% battery power"]

2015-03-31 16:29:54 +0000 Debug: _reduce operation on [object UIATarget] completed in 0.2 seconds
2015-03-31 16:29:54 +0000 Debug: elementReferenceDump (of visible elements) of target():
target()
target().frontMostApp()
mainWindow()
mainWindow().navigationBars()["Illuminator Sample"]
mainWindow().navigationBars()["Illuminator Sample"].staticTexts()["Illuminator Sample"]
mainWindow().tableViews()["Main Menu"]
mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"]
mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"].staticTexts()["Searching Elements"]
mainWindow().tableViews()["Main Menu"].cells()["Wait For Me"]
mainWindow().tableViews()["Main Menu"].cells()["Wait For Me"].staticTexts()["Wait For Me"]
mainWindow().tableViews()["Main Menu"].cells()["Crash The App"]
mainWindow().tableViews()["Main Menu"].cells()["Crash The App"].staticTexts()["Crash The App"]
mainWindow().tableViews()["Main Menu"].cells()["Custom Keyboard"]
mainWindow().tableViews()["Main Menu"].cells()["Custom Keyboard"].staticTexts()["Custom Keyboard"]
target().frontMostApp().windows()[1]
target().frontMostApp().windows()[1].elements()[0]
target().frontMostApp().windows()[1].elements()[0].elements()["Swipe down with three fingers to reveal the notification center., Swipe up with three fingers to reveal the control center, Double-tap to scroll to top"]
target().frontMostApp().windows()[1].elements()[0].elements()["3 of 3 Wi-Fi bars"]
target().frontMostApp().windows()[1].elements()[0].elements()["12:29 PM"]
target().frontMostApp().windows()[1].elements()[0].elements()["100% battery power"]

2015-03-31 16:29:54 +0000 Default: Stack trace from IlluminatorRuntimeVerificationException:
2015-03-31 16:29:54 +0000 Default:    #0: _assertCorrectScreen at Automator.js line 685 col 139
2015-03-31 16:29:54 +0000 Default:    #1: _evaluateScenario at Automator.js line 765 col 47
2015-03-31 16:29:54 +0000 Default:    #2: runScenario at Automator.js line 625 col 49
2015-03-31 16:29:54 +0000 Default:    #3: runScenarioList at Automator.js line 553 col 34
2015-03-31 16:29:54 +0000 Default:    #4: runTaggedScenarios at Automator.js line 495 col 34
2015-03-31 16:29:54 +0000 Default:    #5: IlluminatorIlluminate at Illuminator.js line 36 col 41
2015-03-31 16:29:54 +0000 Default:    #6: global code at IlluminatorGeneratedRunnerForInstruments.js line 20 col 22
2015-03-31 16:29:54 +0000 Debug: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
2015-03-31 16:29:54 +0000 Debug: Step 1 of 1 (homeScreen.verifyIsActive) failed in scenario: "The most basic of all tests" with message: Failed assertion that 'homeScreen' is active
2015-03-31 16:29:54 +0000 Fail: Step 1 of 1 (homeScreen.verifyIsActive) failed in scenario: "The most basic of all tests" with message: Failed assertion that 'homeScreen' is active
2015-03-31 16:29:54 +0000 Debug: Scenario completed in 00:01.46
2015-03-31 16:29:54 +0000 Debug: onScenarioFail callback firing with args: {"scenarioName":"The most basic of all tests","scenarioTags":["functional"],"timeStarted":1427819393.451,"duration":1.4600000381469727}
2015-03-31 16:29:54 +0000 Default: Completed running scenario list (1 of 1 total scenarios)  in 00:01.46
2015-03-31 16:29:54 +0000 Debug: Writing 52 bytes to /Users/iakatz/Code Base/ios-here-newgen/libs/ios-automator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/selectorTimeCostReport.csv as 72 bytes of b64
2015-03-31 16:29:55 +0000 Default: Overall time spent evaluating soft selectors: 00:00 - full report at /Users/iakatz/Code Base/Illuminator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/selectorTimeCostReport.csv
2015-03-31 16:29:55 +0000 Debug: complete callback firing with args: {"scenarioCount":1,"timeStarted":1427819393.451,"duration":1.4600000381469727}
Instruments Trace Complete (Duration : 13.561836s; Output : /Users/iakatz/Code Base/Illuminator/buildArtifacts/instruments/instrumentscli0.trace)
Automation completed in 00:00:15
Running /Users/iakatz/Code Base/Illuminator/scripts/kill_all_sim_processes.sh
Killing all top-level Xcode 5 simulator processes...
No matching processes belonging to you were found
Killing all top-level Xcode 6 simulator processes...
Killing ScriptAgent...
No matching processes belonging to you were found
Killing any xpcproxy_sim zombies...
Result: !
1 of 1 tests FAILED
```


### OK, What Does This Output Mean?

There are a few notable bits in this output.

* `Start: The most basic of all tests` - our test was executed
* `Default: STEP 0: Reset automator for new scenario` followed by `Bridge running native method via 'Bridge_call_1': selector='returnToMainMenu', arguments=''` - our pre-scenario callback is being executed
* `STEP 1 of 1: (SampleApp.homeScreen.verifyIsActive) Null op to verify that the homeScreen screen is active` - the only step in our scenario is executing

Then, there is the failure itself: `FAILED: Failed assertion that 'homeScreen' is active`, followed by a lot of output:

1. a dump of the elements on the screen
2. a dump of the *visible* elements on the screen
3. a Javascript stack trace

We can see that the `_assertCorrectScreen` function is where the failure occurred.  Of course, we expected this when we defined that screen in `Home.js`!  The offending line the return value of `false`:

```javascript
appmap.createOrAugmentApp("SampleApp").withScreen("homeScreen")
    .onTarget("iPhone", function() { return false; });  // in other words, pretend the screen is never active
```

### Making Our First Test Pass (But Still Be Useless)

We need to improve the "screen is active" function to return `true` when the home screen is, in fact, active.  That doesn't seem so hard, because Illuminator printed out the list of copy-pastable element references when the test failed.  We'll assume that the home screen is defined by the existence of the main menu, `mainWindow().tableViews()["Main Menu"]`.  We'll also take advantage of that output to define our first action on the screen: opening the "search elements" menu item.

```javascript
function homeScreenIsActive() {
    return isNotNilElement(mainWindow().tableViews()["Main Menu"]);
}

function actionOpenSearch() {
    mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"].tap();
}

appmap.createOrAugmentApp("SampleApp").withScreen("homeScreen")
    .onTarget("iPhone", homeScreenIsActive)

    .withAction("openSearch", "Open the element search screen")
    .withImplementation(actionOpenSearch);
```

Rerunning the same command as before, the test passes.

```
$ ruby scripts/automationTests.rb --scheme AutomatorSampleApp --appName AutomatorSampleApp --entryPoint runTestsByTag --tags-all functional --implementation iPhone --verbose --simDevice "iPhone 5" --simVersion "7.1"

        [ messages removed ]

2015-03-31 17:15:04 +0000 Default: 1 scenarios to run
2015-03-31 17:15:04 +0000 Debug: ###############################################################
2015-03-31 17:15:04 +0000 Start: The most basic of all tests
2015-03-31 17:15:04 +0000 Default: Scenario tags are [functional]
2015-03-31 17:15:04 +0000 Default: Running scenario 1 of 1
2015-03-31 17:15:04 +0000 Debug: (No previous test)
2015-03-31 17:15:04 +0000 Debug: ----------------------------------------------------------------
2015-03-31 17:15:04 +0000 Default: STEP 0: Reset automator for new scenario
2015-03-31 17:15:04 +0000 Debug: Bridge running native method via 'Bridge_call_1': selector='returnToMainMenu', arguments=''
2015-03-31 17:15:04 +0000 Debug: Bridge waiting for acknowledgment of UID 'Bridge_call_1' from $ /usr/bin/ruby /Users/iakatz/Code Base/Illuminator/scripts/UIAutomationBridge.rb --callUID=Bridge_call_1 --selector=returnToMainMenu
2015-03-31 17:15:05 +0000 Debug: ----------------------------------------------------------------
2015-03-31 17:15:05 +0000 Default: STEP 1 of 1: (SampleApp.homeScreen.verifyIsActive) Null op to verify that the homeScreen screen is active
2015-03-31 17:15:05 +0000 Pass: The most basic of all tests
2015-03-31 17:15:05 +0000 Debug: Scenario completed in 00:01.4
2015-03-31 17:15:05 +0000 Debug: onScenarioPass callback firing with args: {"scenarioName":"The most basic of all tests","scenarioTags":["functional"],"timeStarted":1427822104.142,"duration":1.0369999408721924}
2015-03-31 17:15:05 +0000 Default: Completed running scenario list (1 of 1 total scenarios)  in 00:01.4
2015-03-31 17:15:05 +0000 Debug: Writing 52 bytes to /Users/iakatz/Code Base/Illuminator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/selectorTimeCostReport.csv as 72 bytes of b64
2015-03-31 17:15:06 +0000 Default: Overall time spent evaluating soft selectors: 00:00 - full report at /Users/iakatz/Code Base/Illuminator/scripts/classes/../../buildArtifacts/UIAutomation-outputs/selectorTimeCostReport.csv
2015-03-31 17:15:06 +0000 Debug: complete callback firing with args: {"scenarioCount":1,"timeStarted":1427822104.141,"duration":1.0379998683929443}
Instruments Trace Complete (Duration : 12.634939s; Output : /Users/iakatz/Code Base/Illuminator/buildArtifacts/instruments/instrumentscli0.trace)
Automation completed in 00:00:16
All 1 tests PASSED
```

### A Non-useless Test

Let's augment our test to include our first action.  Note that `.verifyIsActive` is called implicitly inside *every* screen action, so we simply replace the first line.

```javascript
automator.createScenario("The most basic of all tests", ["functional"])
    .withStep(app.homeScreen.openSearch);
```

Rerunning the test from the command line, we see the following output:

```
2015-03-31 17:28:37 +0000 Default: STEP 1 of 1: (SampleApp.homeScreen.openSearch) Open the element search screen
2015-03-31 17:28:37 +0000 Debug: target.frontMostApp().mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"].tap()
2015-03-31 17:28:38 +0000 Pass: The most basic of all tests
2015-03-31 17:28:38 +0000 Debug: Scenario completed in 00:01.20
```

The second line comes from the UIAutomation library itself.  This is an indication that we successfully found the element we were looking for and executed the `.tap()` method on it, but we really didn't stick around to see what happened.  To verify that `.tap()` causes the behavior that we want, we will have to wait, see, and verify.

Illuminator comes with some pre-defined actions (see the end of [the AppMap documentation](AppMap.md)), and one of them will be very helpful now: `logAccessors`.  We will add a parameter for 3 seconds of delay, to allow any animations to settle.

```javascript
automator.createScenario("The most basic of all tests", ["functional"])
    .withStep(app.homeScreen.openSearch)
    .withStep(ia.do.logAccessors, {delay: 3});
```


Rerunning the test command, we see this:

```
2015-03-31 17:44:08 +0000 Debug: ----------------------------------------------------------------
2015-03-31 17:44:08 +0000 Default: STEP 2 of 2: (Illuminator.do.logAccessors) Log the list of valid element accessors {delay: 3}
2015-03-31 17:44:11 +0000 Debug: _reduce operation on [object UIAWindow] completed in 0.1 seconds
2015-03-31 17:44:11 +0000 Debug: elementReferenceDump of mainWindow:
mainWindow
mainWindow.buttons()["Done"]
mainWindow.navigationBars()["Searching For Elements"]
mainWindow.navigationBars()["Searching For Elements"].buttons()["Back"]
mainWindow.navigationBars()["Searching For Elements"].buttons()["UINavigationBarBackIndicatorDefault.png"]
mainWindow.navigationBars()["Searching For Elements"].buttons()["Done"]
mainWindow.navigationBars()["Searching For Elements"].images()[0]
mainWindow.navigationBars()["Searching For Elements"].images()[0].images()[0]
mainWindow.navigationBars()["Searching For Elements"].staticTexts()["Searching For Elements"]
mainWindow.textFields()[0]
mainWindow.toolbars()[0]
mainWindow.toolbars()[0].images()[0]
mainWindow.toolbars()[0].images()[1]

2015-03-31 17:44:11 +0000 Pass: The most basic of all tests
```

Looks like we've made it to our second screen!  Let's automate that one as well.


### Adding a New Screen Definition

We'll put our new screen definition in `screens/SearchingElements.js`, copying the same format from `Home.js`:

```javascript
#import "../Common.js";

function searchingElementsScreenIsActive() {
    return isNotNilElement(mainWindow().navigationBars()["Searching For Elements"]);
}

function actionSearchingElementsBack() {
    mainWindow().navigationBars()["Searching For Elements"].buttons()["Back"].tap();
}

appmap.createOrAugmentApp("SampleApp").withScreen("searchingElements")
    .onTarget("iPhone", searchingElementsScreenIsActive)

    .withAction("back", "Go back from the element search screen")
    .withImplementation(actionSearchingElementsBack);

```

Next, we need to import this new screen in `screens/AllScreens.js`:

```javascript
#import "Bridge.js";
#import "Home.js";
#import "SearchingElements.js";
```

Finally, we'll update our test: we want to go from the home screen to the "Searching for elements" screen, and back again.

```javascript
automator.createScenario("To a new screen and back again", ["functional"])
    .withStep(app.homeScreen.openSearch)
    .withStep(app.searchingElements.back)
    .withStep(App.homeScreen.verifyIsActive);
```

What happens when we run this?

```
2015-04-01 17:28:59 +0000 Debug: ###############################################################
2015-04-01 17:28:59 +0000 Start: To a new screen and back again
2015-04-01 17:28:59 +0000 Default: Scenario tags are [functional]
2015-04-01 17:28:59 +0000 Default: Running scenario 1 of 1
2015-04-01 17:28:59 +0000 Debug: (No previous test)
2015-04-01 17:28:59 +0000 Debug: ----------------------------------------------------------------
2015-04-01 17:28:59 +0000 Default: STEP 0: Reset automator for new scenario
2015-04-01 17:28:59 +0000 Debug: Bridge running native method via 'Bridge_call_1': selector='returnToMainMenu', arguments=''
2015-04-01 17:28:59 +0000 Debug: Bridge waiting for acknowledgment of UID 'Bridge_call_1' from $ /usr/bin/ruby /Users/iakatz/Code Base/ios-here-newgen/libs/ios-automator/scripts/UIAutomationBridge.rb --callUID=Bridge_call_1 --selector=returnToMainMenu
2015-04-01 17:29:00 +0000 Debug: ----------------------------------------------------------------
2015-04-01 17:29:00 +0000 Default: STEP 1 of 3: (SampleApp.homeScreen.openSearch) Open the element search screen
2015-04-01 17:29:00 +0000 Debug: target.frontMostApp().mainWindow().tableViews()["Main Menu"].cells()["Searching Elements"].tap()
2015-04-01 17:29:01 +0000 Debug: ----------------------------------------------------------------
2015-04-01 17:29:01 +0000 Default: STEP 2 of 3: (SampleApp.searchingElements.back) Go back from the element search screen
2015-04-01 17:29:01 +0000 Debug: target.frontMostApp().mainWindow().navigationBars()["Searching For Elements"].buttons()["Back"].tap()
2015-04-01 17:29:01 +0000 Debug: ----------------------------------------------------------------
2015-04-01 17:29:01 +0000 Default: STEP 3 of 3: (SampleApp.homeScreen.verifyIsActive) Null op to verify that the homeScreen screen is active
2015-04-01 17:29:01 +0000 Pass: To a new screen and back again
```

Not bad!  These are the basics.


Where You Might Run Into Trouble As You Take This Further
---------------------------------------------------------

### Immediacy in "Screen Is Active" Functions

Consider the function we wrote to see whether the "Searching For Elements" screen was active:

```javascript
function searchingElementsScreenIsActive() {
    return isNotNilElement(mainWindow().navigationBars()["Searching For Elements"]);
}
```

This function returns immediately with a true or false response (it could also throw an exception about undefined methods if it evaluated a more complex hierarchy, but part of it was missing).  In real apps, it may take several seconds to transition between screens (e.g. during the process of logging in or processing a network request).  This would likely cause an error like `Failed assertion that 'searchingElements' is active`.

It is much better practice to use a [Selector](Selectors.md) and a wait function in these situations.

For example, creating a 10-second timeout for the "Searching For Elements" screen would produce the following code:

```javascript
function searchingElementsScreenIsActive() {
    var expectedExistence = true;
    try {
        var navBar = mainWindow().waitForChildExistence(10, expectedExistence, "Searching for Elements navbar", function (mw) {
            return mw.navigationBars()["Searching For Elements"]);
        });
        return true;  // we don't actually care about the navBar.  If we got here, we found it and therefore the screen is active.
    } catch (e) {
        UIALogger.logDebug("searchingElementsScreenIsActive failed: " + e.toString());
        return false;
    }
}
```

In other words, wait up to 10 seconds while continuously evaluating the selector (the snippet starting with `function (mw) {`) until it produces a valid element.

This code is boilerplate, so if you're into the whole brevity thing then you can take advantage of the AppMap's ActionBuilder.  All you need is a selector that works relative to UIATarget():

```javascript
var ab = appmap.actionBuilder.makeAction;

// same as in previous example, but we're giving it a name and making it relative to target() instead of mainWindow()
var mySelectorFunction = function(targ) {
    return targ.frontMostApp().mainWindow().navigationBars()["Searching For Elements"]);
};

var searchingElementsScreenIsActive = ab.screenIsActive.byElement("searchingElements",          // the screen name (for logging)
                                                                  "Searching Elements navbar",  // what we are looking for (for logging)
                                                                  mySelectorFunction,           // selector to use
                                                                  10));                         // timeout to use
```