UI Automation System
====================

This system is responsible for the integration testing of the iOS app.  It provides
structures to define the components of integration tests, assemble test scenarios, and
execute some or all of those scenarios.


Quick Start
-----------

A script is available to run integration test files from the command line: `automationTests.rb`.

Example usage from of sample app project directory:
```
$ ruby ../../scripts/automationTests.rb -x /Applications/Xcode.app -p ../SampleTests/tests/AllTests.js -a AutomatorSampleApp -s AutomatorSampleApp -i iPhone -t test,mocked
```

To see a list of defined tags, run the command with no arguments (or `--skip-build` to save time if you've already compiled):
```
$ ruby scripts/automationTests.rb
```


This should launch an instance of the simulator (possibly requiring credentials from OSX) and
then run the test script, outputting the log to the terminal.


Architecture of an Automation Test Sequence
-------------------------------------------

The central component of integration testing is the `automator`.  `automator` contains a set of test scenario, each scenario tagged with some number of text tags (*e.g.* `["nohardware", "invoice"]`).

Each test scenario is made of a sequence of steps, called actions.  Actions describe one possible interaction that a user may have with a given screen in the app. For example, the `orderEntry` screen has automation actions for keying in an amount to charge, and selecting a payment type.

Since actions are only valid from their host screen, a validation function is run for each action to assert that the appropriate screen is visible.  To perform no action (and only assert that the screen is visible), a default action `verifyIsActive( )` is provided in every defined screen.

Not all screens and actions are available on all devices -- differences between iPhone and iPad might mean that an action is performed in subtly different ways on each device.  Therefore, actions have implementations that are defined for each possible device.

The available apps, screens, and actions are laid out in an organizational tool called the `appmap`.  This module captures everything that the `automator` knows about the functionality of iOS targets.

### In summary
An **app** has **screens**.
A **screen** has a function to verify whether it is active, and **action**s.
An **action** has a set of **parameter**s and a mapping of **device**s to **implementation**s.
The **automator** defines **test scenario**s comprised of a set of **action**s.


Creating Scenarios
------------------

`automator.createScenario` takes 2 arguments:
* the test name
* the tags (describing the test, and used to decide which tests should run)

When a test is run with `automator.runSupportedScenarios()`, test will run if:
* no tags are specified in tagsAny, or at least one of the specified tags matches one of the scenario's tags
* all of the tags specificed in tagsAll are present in the scenario's tags
* none of the tags specified in tagsNone are present in the scenario's tags

The `createScenario` method should be followed by one or more `.withStep` methods.

Here is an example test, which simply logs in and back out again:

```javascript
pph = appmap.apps["PayPalHere"]; // this would be provided by the script run environment

automator.createScenario('Login with valid user', ['login'])
    .withStep(pph.login.withCredentials, {
            username: "9red@sox.win",
                password: "11111111"
                })
    .withStep(pph.orderEntry.openLeftMenu)
    .withStep(pph.leftMenu.logout);
```

The steps specify the screen (e.g. `orderEntry`) and action (e.g. `openLeftMenu`) to execute.  If the step requires parameters, they are specified as an optional second argument.


Creating Screens and Actions
----------------------------

All screens and actions (including the devices on which these screens and actions exists) are defined using the `appmap`.  The files in which these definitions are laid out are in `apps/` (e.g. `apps/PayPalHere.js`).

Creating an app in the AppMap is straightforward:

```javascript
#import "../common/AppMap.js";

appmap.createApp("PayPalHere");
```

Defining a device screen is also straightforward:

```javascript
appmap.augmentApp("PayPalHere").withScreen("login")
    .onDevice("iPhone", loginScreenIsActive)
    .onDevice("iPad", loginScreenIsActiveIpad)

    .withAction("withCredentials", "Log in with given user/password")
    .withImplementation(actionLoginWithCredentials, "iPhone")
    .withImplementation(actionLoginWithCredentialsIpad, "iPad")
    .withParam("username", "username to use for login", true, true)
    .withParam("password", "password for login", true)
    .withParam("clear", "Whether to clear the field first", false);
```

In this example, the `withScreen` method takes 1 argument: the screen name.

`onDevice` takes 2 arguments: device on which this function will be used, and the function (taking no arguments, returning boolean) that will specify at runtime whether the screen is currently active.

The `withAction` method takes 2 arguments: the action name, the text that will be displayed in the automator when the action is run.

The `withImplementation` function take the function (which can take one optional argument -- an associative array) that is the action itself, and the device that will use this implementation.  The device must match one of the defined `onDevice` devices.  If this argment is not provided, a default value will be used -- it will be considered to be part of every device.

The `withParam` method specifies the parameters that may be given (as associative array keys) to the action.  The 4 arguments are the key name, the description of the parameter, whether the parameter is required, and whether the parameter's value should be included in the action description.

Some actions are simple enough to be defined in-line, and some helper functions exist to define simple action functions (like navbar button presses).  All other actions should be defined in files located in `screens/` and that file listed in the imports section of `screens/AllScreens.js`.

**Note:** All screens come with 2 automatically-defined actions: `verifyIsActive` and `verifyNotActive`.  These actions do nothing but run the screen's defined function for verifiying whether the screen is active, and throw an error if it does not meet the expectation of active or inactive.  `verifyIsActive` is run implicitly before any action defined with `.withAction`, so it is most commonly used to verify that the last step of an automation test ended on the appropriate screen.

FAQ
---

#### How do I create a scenario?
Using `automator.createScenario('The name of my test', ['mytag1', 'mytag2']);`

#### How do I add steps to my scenario?
After the createScenario line, add one or more `.withStep(d.actionName.stepName)` lines.

#### How do I specify parameters for steps in a test scenario that I'm defining?
Add a second argument to `withStep`, e.g. `.withStep(d.actionName.stepName, {myKey: "myValue"})`.

#### Where do I find the list of screens and actions?
They are listed in `devices/*.js`.  Note that the screen names and action names are defined as quoted strings but referenced as identifiers.

#### How do I run just one test?
Add your own custom tag to `createScenario` and specify that tag with `--tags-all` on the command line when you run it.


#### How do I define tests for a specific device?
All tests are device-agnostic, but the `automator` will only run tests for which all the steps are defined (or default) for the chosen device.


Quirks
------

Apple's nonstandard javascript implementation in their Instruments App can be confusing, especially with respect to `#import` statements.

First, imagine `my-source.js`:
```javascript
function doSomething() {
    // it could be anything
}
```

Next, we will define `my-intermediate.js`:
```javascript
#import "my-source.js";
//                    ^--we include the semicolon
//                       to please the formatter script
var functionTable = {myKey: doSomething}; // refer to our function
```

So far, so good; this will interpret appropriately.

Now, we define `my-bad-destination.js`:
```javascript
#import "my-intermediate.js";
functionTable.myKey(); // "undefined variable doSomething in my-intermediate"
```

The problem is that `functionTable.myKey()` refers to a function that was defined in a file that was not imported *directly by this script*.  In other words, this is the (unfortunate and counterintuitive) solution:

`my-good-destination.js`:
```javascript
#import "my-source.js"; // even though we never refer to it
#import "my-intermediate.js";
functionTable.myKey(); // now works fine
```
