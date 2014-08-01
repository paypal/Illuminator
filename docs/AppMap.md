
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

The `withImplementation` function takes the function (which can take one optional argument -- an associative array) that is the action itself, and the device that will use this implementation.  The device must match one of the defined `onDevice` devices.  If this argment is not provided, a default value will be used -- it will be considered to be part of every device.

The `withParam` method specifies the parameters that may be given (as associative array keys) to the action.  The 4 arguments are the key name, the description of the parameter, whether the parameter is required, and whether the parameter's value should be included in the action description.

Some actions are simple enough to be defined in-line, and some helper functions exist to define simple action functions (like navbar button presses).  All other actions should be defined in files located in `screens/` and that file listed in the imports section of `screens/AllScreens.js`.

**Note:** All screens come with 2 automatically-defined actions: `verifyIsActive` and `verifyNotActive`.  These actions do nothing but run the screen's defined function for verifiying whether the screen is active, and throw an error if it does not meet the expectation of active or inactive.  `verifyIsActive` is run implicitly before any action defined with `.withAction`, so it is most commonly used to verify that the last step of an automation test ended on the appropriate screen.


Common Actions
--------------

Many actions are simple -- tapping a button, entering text, verifying that an element is visible, etc.  Rather than create action functions that wrap this behavior (and then refer to that function in the AppMap), the AppMap provides an `actionBuilder` module to allow creation of action functions in a more straightforward syntax.

```javascript
 var ab = appmap.actionBuilder.makeAction;  // abbrieviate the module name for the action builder

 appmap.createOrAugmentApp("PayPalHere").withScreen("itemOptionValue")
     .onDevice("iPhone", itemOptionValueScreenIsActive, "iPhone")

     .withAction("verifyDeleteButton", "Verify that the delete button is visible or not visible")
     .withImplementation(ab.verifyElement.visibility({name: "Delete", UIAtype: "UIAButton"}, "Delete"))
     .withParam("expected", "The expected visibility state", true, true)

     .withAction("enterName", "Enter an option value name")
     .withImplementation(ab.element.typeString({name: "Item Option Name"}, "Item option name"))
     .withParam("text", "The text to enter.", true, true)
     .withParam("clear", "Whether to clear the textbox first.", false, true)

     .withAction("done", "Save item option value entry and go back to previous screen")
     .withImplementation(ab.element.tap({name: "Done", UIAType: "UIAButton"}, "Done button"))
 ```

