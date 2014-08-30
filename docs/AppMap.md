AppMap.js Reference
===================

To explain the AppMap, it's necessary to understand Illuminator's automation methodology.


Automation Methodology in Illuminator
-------------------------------------

There are 4 general classes of errors that Illuminator can highlight in your app.

1. **Right element, wrong interaction** -- instances of screen elements failing to interact as expected.  For example:
    * A button that can't be tapped because has failed to become enabled
    * A textbox that isn't editable
    * A static text with the wrong text
2. **Right screen, wrong element(s)** -- instances of screen elements failing to match their expected structure.  For example:
    * An incorrect number of cells in a table
    * Duplicate instances of an element in the tree
    * Elements being laid out in an incorrect order or with the wrong type
3. **Right app, wrong screen** -- instances of app screens being visible at the wrong times. For example:
    * Being unable to advance to the next screen
    * Not seeing an error screen after supplying bad input data
    * Seeing an initial setup screen more than once
4. **Fatal errors** -- instances of problems that are outside the realm of the app.  For example:
    * Segmentation faults
    * Unexpected instances of the app going into the background

**The AppMap is the repository of what constitutes the "right screen", "right element(s)", and "right interaction(s)" in your app** (not including fatal errors, since they *always* indicate a problem). Essentially, the AppMap names all the actions that your app can perform, and the screens (corresponding roughly to the states) in which those actions are valid.


Building your apps in the AppMap
--------------------------------

The overview of building apps in the AppMap is as follows:

1. Define your **app**
2. Define one or more **screen**s for your app
3. Define what **target** devices will have this screen
4. Define one or more **action**s will be available on this screen
5. Define what **implementation** this action will use for each target device on which it is supported
6. Define zero or more **parameter**s that control the action

For an example of this, see the [Quick Start guide](README.md).

Note 1:
> All **target**s must be defined for a screen before the first **action** is defined.

Note 2: 
> The AppMap adds two special **action**s to each **screen** automatically: `verifyIsActive` and `verifyNotActive`.  These actions assert that the given screen is respectively active or not active  (based on the `isActiveFn` provided to `.onTarget`) -- throwing exceptions otherwise.  A `verifyIsActive` assertion is run implicitly before any action defined with `.withAction`, so it is most commonly used to verify that the last step of an automation test ended on the appropriate screen.

Note 3:
> Actions can be parameterized (e.g. for entering variable strings, waiting a variable length of time, defining expected values, etc).  All functions that implement AppMap actions must take either *no* arguments, or *one* argument -- an associative array of named parameters.

Building input methods in the AppMap
------------------------------------

For control over fields that bring up a non-standard keyboard (such as a date picker or custom keyboard), a set of definition functions is available.

1. Define your **input method**
2. Define zero or more **feature**s for your input method

Defined input methods can be accessed via `appmap.inputMethods[methodName]`.


AppMap Method Reference
-----------------------

The AppMap is a singleton object called `appmap`.  Its methods -- most meant to be chained together -- are as follows:

#### `.createApp(appName)`
Create a new app with the given `appName`, and indicate that any following screen definitions should be associated with this new app.  Returns a reference to the AppMap.

#### `.hasApp(appName)`
Return true if `appName` is defined in the AppMap.

#### `.augmentApp(appName)`
Indicate that any following screen definitions should be associated with the app called `appName`.  Returns a reference to the AppMap.

#### `.createOrAugmentApp(appName)`
Create a new app with the given `appName` if it does not already exist, and indicate that any following screen definitions should be associated with this new app.  Returns a reference to the AppMap.

#### `.withNewScreen(screenName)`
Create a new screen with the given `screenName`, and indicate that any following target or action definitions should be associated with this new screen.  Returns a reference to the AppMap.

#### `.hasScreen(appName, screenName)`
Return true if `screenName` is defined in the AppMap for `appName`.

#### `.augmentScreen(screenName)`
Indicate that any following target or action definitions should be associated with the screen called `screenName`.  Returns a reference to the AppMap.

#### `.withScreen(screenName)`
Create a new screen with the given `screenName` if it does not already exist, and indicate that any following target or action definitions should be associated with this new screen.  Returns a reference to the AppMap.

#### `.onTarget(targetName, isActiveFn)`
Enable the screen on the target device called `targetName`, relying on the function defined by `isActiveFn` to return `true` when the screen is currently active.  Returns a reference to the AppMap.

#### `.withNewAction(actionName, desc)`
Create a new action with the given `actionName`, use the `desc`ription for logging purposes, and indicate that any following implementation or parameter definitions should be associated with this new action.  Returns a reference to the AppMap.

#### `.hasAction(appName, screenName, actionName)`
Return true if the action called `actionName` is defined in the AppMap for `appName` and the screen  `screenName`.

#### `.augmentScreen(actionName)`
Indicate that any following implementation or parameter definitions should be associated with the action called `actionName`.  Returns a reference to the AppMap.

#### `.withAction(actionName)`
Create a new action with the given `actionName` if it does not already exist, and indicate that any following implementation or parameter definitions should be associated with this new action.  Returns a reference to the AppMap.

#### `.withImplementation(actionFunction, targetName)`
Use the given function `actionFunction` as the implementation for the current action when the target device is `targetName`.  `targetName` is optional -- if omitted, the `actionFunction` will carry out the named action on *every* target device.  Returns a reference to the AppMap.

Notes on `actionFunction`s

* If a parameterized action function is desired for an implementation, that function may take a single argument -- an associative array containing the named parameters.  
* It is acceptable to use a no-argument function for an implementation if no parameters are required.  
* Any return value of action functions is ignored.

One further note on implementation of actions:
> Actions are not expected to have an implementation for every device type; it is entirely appropriate to leave some actions undefined for certain targets that do not in fact support those actions.  This will not result in test failure, because the [Automator](Automator.md) will not run test scenarios whose sequence of actions are unsupported on the target device.


#### `.withParam(paramName, desc, required, useInSummary)`
Define a parameter on the current action, named `paramName` and having the description `desc`.  If `required`, the Automator will throw an exception if this parameter is not provided to the action.  `useInSummary` controls whether the Automator should log the value of this parameter to the console (e.g. the user might prefer to set this to `false` in cases where the value of the parameter will be a large amount of text or a function definition).  `useInSummary` is optional and defaults to `false`.  Returns a reference to the AppMap.

#### `.createInputMethod(inputMethodName, isActiveFn, selector)`
Define an input method called `inputMethodName` with a function `isActiveFn` that returns `true` when this input method is accessible and visible.  Also, a `selector` to be used in `target().getChildElement(selector)` to retrieve the root element of this input method.

#### `.hasinputMethod(inputMethodName)`
Return `true` if `inputMethodName` is defined in the AppMap.

#### `.augmentInputMethod(inputMethodName)`
Indicate that any following feature definitions should be associated with the input method called `inputMethodName`.

#### `.withFeature(featureName, implementationFunction)`
Use the given function `implementationFunction` as the implemenation for the feature called `featureName`.


#### `.getApps()`
Returns an array of the app names that are defined in the AppMap.

#### `.getScreens(appName)`
Returns an array of the screen names that are defined in the app `appName` in the AppMap.

#### `.getInputMethods()`
Returns an array of the input method names that are defined in the AppMap.

#### `.toMarkdown()`
Returns a string containing a markdown description of all the apps, screens, targets, actions, implementations, and parameters in the AppMap.




ActionBuilder Reference
----------------------------

The implementation of every action is a function.  However, most such functions will involve simple interactions with screen elements -- saying whether they exist, tapping them, typing on them, etc.  AppMap provides the **ActionBuilder** to factor out the boilerplate code required for such functions.

The ActionBuilder is located at `appmap.actionBuilder.makeAction`.  It has the following submodules:

* `screenIsActive`: containing functions to build functions to indicate whether a screen is active
* `.verifyElement`: containing functions to build actions for verifying element properties
* `.element`: containing functions to build actions for interactions with elements
* `.selector`: containing functions that perform actions in response to a selector

The following functions are defined relative to the ActionBuilder.

#### `.screenIsActive.byElement(screenName, elementName, selector, timeout)`
Return a function (taking no arguments) that waits up to `timeout` seconds for `selector` to become valid.  If the `selector` becomes valid, the function returns true.  Otherwise, it logs a message about `screenName` not being active because the selector referring to `elementName` did not become valid, and returns false.

#### `.verifyElement.editability(selector, elementName, retryDelay)`
Return a function (taking an object with fields {`expected`: boolean} as its only argument) that verifies whether the element returned by the `selector` called `elementName` matches the editability state `expected`.

#### `.verifyElement.enabled(selector, elementName, retryDelay)`
Return a function (taking an object with fields {`expected`: boolean} as its only argument) that verifies whether the element returned by the `selector` called `elementName` matches the `.enabled()` state `expected`.

#### `.verifyElement.existence(selector, elementName, retryDelay)`
Return a function (taking an object with fields {`expected`: boolean} as its only argument) that verifies whether the `selector` called `elementName` produces an element (or not) according to `expected`.

#### `.verifyElement.visibility(selector, elementName, retryDelay)`
Return a function (taking an object with fields {`expected`: boolean} as its only argument) that verifies whether the element returned by the `selector` called `elementName` matches the `.isVisible()` state `expected`.

#### `.element.svtap(selector, elementName, retryDelay)`
Return a function (taking no arguments) that `.svtap(4)`s the element returned by the `selector` called `elementName`.

#### `.element.tap(selector, elementName, retryDelay)`
Return a function (taking no arguments) that `.tap()`s the element returned by the `selector` called `elementName`.

#### `.element.typeString(selector, elementName, retryDelay)`
Return a function (taking an object with fields {`text`: string, `clear`: boolean} as its only argument) that types the `text` into the element returned by the `selector` called `elementName` (`clear`ing it first if desired).

#### `.element.vtap(selector, elementName, retryDelay)`
Return a function (taking no arguments) that `.vtap(4)`s the element returned by the `selector` called `elementName`.

#### `.selector.verifyExists(retryDelay, parentSelector)`
Return a function (taking an object with fields {`selector`: selector} as its only argument) that asserts the existence of the element returned by the `selector` from the element returned by the `parentSelector`.
