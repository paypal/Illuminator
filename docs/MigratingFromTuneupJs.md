Migrating To Illuminator From `tuneup_js`
=========================================

If you like Alex Vollmer's [tuneup_js](https://github.com/alexvollmer/tuneup_js) as much as we do, you'll be glad to see a lot of the same functionality implemented in Illuminator.  We've even improved it in some ways, so if you want to check that out then here's how you'd migrate your tuneup-style stests over to Illuminator.


Small, but VERY IMPORTANT Stuff
-------------------------------

In corner cases, Springboard popups (_e.g._ soliciting the user's permission for your app to use location or send push notifications) can disrupt references to `target` and `mainWindow`, which are generally provided to you by Instruments.  Illuminator turns these shortcut references into **function calls**, so they are subtly-but-seriously different:

* `target()` - Returns `UIATarget.localTarget()`, just like `target` used to do.
* `mainWindow()` - Returns `UIATarget.localTarget().frontMostApp().mainWindow()` like `mainWindow` used to do.

Additionally, there are a few more convenience functions:

* `host()` - Returns `UIATarget.localTarget().host()`
* `__file__()` - Returns the name of the file in which this line of code is found.
* `__function__()` - Returns the name of the function in which this line of code is found.


Defining Tests
--------------

The only bad thing about tests in tuneup.js was that they could get a little difficult to read, and it was slightly awkward to reuse components.  Consider the following script recorded in Instruments and turned into a tuneup.js test case (comments and assertions removed; just a "sunny day" runthrough):

```javascript
test("Select invoice payment method, cancel flow, do invoice payment", function(target, app) {
    app.mainWindow().elements()["Login Container"].textFields()["Login Email Text field"].typeString("f@ke.user");
    app.mainWindow().elements()["Login Container"].secureTextFields()["Email Password Text Field"].typeString("1234");
    app.mainWindow().buttons()["Log In with PayPal"].tap();
    app.mainWindow().scrollViews()[0].keys()["1"].tap();
    app.mainWindow().scrollViews()[0].keys()["2"].tap();
    app.mainWindow().scrollViews()[0].keys()["3"].tap();
    app.mainWindow().scrollViews()[0].keys()["4"].tap();
    app.mainWindow().scrollViews()[0].keys()["5"].tap();
    app.navigationBar().buttons()[2].tap();
    app.mainWindow().tableViews()["Payment Type Table View"].cells()["Invoice"].tap();
    app.mainWindow().tableViews()["Invoice Payment Table"].waitUntilVisible(5);
    app.mainWindow().navigationBars()[0].buttons()[1].tap();
    app.navigationBar().buttons()[2].tap();
    app.mainWindow().tableViews()["Payment Type Table View"].cells()["Invoice"].tap();
    app.mainWindow().tableViews()["Invoice Payment Table"].cells().firstWithPredicate("name = 'First Name'").scrollToVisible();
    app.mainWindow().tableViews()["Invoice Payment Table"].cells().firstWithPredicate("name = 'First Name'").typeString("Jonny");
    app.mainWindow().tableViews()["Invoice Payment Table"].cells().firstWithPredicate("name = 'Last Name'").scrollToVisible();
    app.mainWindow().tableViews()["Invoice Payment Table"].cells().firstWithPredicate("name = 'Last Name'").typeString("Quest");
    app.mainWindow().tableViews()["Invoice Payment Table"].cells().firstWithPredicate("name = 'Email Address'").scrollToVisible();
    app.mainWindow().tableViews()["Invoice Payment Table"].cells().firstWithPredicate("name = 'Email Address'").typeString("jq@palm.com");
    app.mainWindow().navigationBars()[0].buttons()[2].tap();
    app.mainWindow().buttons()["Receipt Sent Done Button"].tap();
});
```

But what is it actually doing?  Here is the exact same test in Illuminator:

```javascript
var pph = appmap.apps["PayPalHere"];
automator.createScenario('Select invoice payment method, cancel flow, do invoice payment', ['invoice', 'US', 'C142'])
    .withStep(pph.login.withDefaultUser)
    .withStep(pph.orderEntry.chargeAmount, {amount: 123.45})
    .withStep(pph.paymentOptions.byInvoice)
    .withStep(pph.invoicePayment.back)
    .withStep(pph.orderEntry.charge)
    .withStep(pph.paymentOptions.byInvoice)
    .withStep(pph.invoicePayment.sendDefaultInvoiceUponReceipt, {
            firstName: "Jonny",
            lastName: "Quest",
            email: "jq@palm.com"})
    .withStep(pph.confirmation.selectNewSale)
    .withStep(pph.orderEntry.verifyIsActive);
```

This has the benefit of being easier to read, and is built from reusable actions (with some launch-time error checks).  On the other hand, this takes a non-trivial amount of setup done in advance via Illuminator's [AppMap](AppMap.md) (see the [Practical Introduction](PracticalIntroduction.md) for a taste of how to do that).  If you just want to get your old tests up and running ASAP, a convenience function is provided for you that wraps your entire test block into an Illuminator test action.

```javascript
var ia = appmap.apps["Illuminator"];
automator.createScenario('Select invoice payment method, cancel flow, do invoice payment', ['myDefaultTag'])
    .withStep(ia.do.testAsAction, {test: function () {
        mainWindow().elements()["Login Container"].textFields()["Login Email Text field"].typeString("f@ke.user");
        //
        //                       -- contents snipped --
        //
        app.mainWindow().buttons()["Receipt Sent Done Button"].tap();
    }});
```


Running Tests
-------------

You have to use the [Illuminator test runner](Commandline.md).  If this won't serve your needs, please get in touch with us and we'll find a way to help.


Assertions
----------

How to implement each of the following tuneup.js functions in Illuminator.  Note that in these examples, all `message` arguments are assumed to be provided; there are no default messages.

### `fail(message)`
`throw new IlluminatorRuntimeFailureException(message)`

### `assertTrue(expression, message)`
`if (!expression) throw new IlluminatorRuntimeVerificationException(message)`

### `assertFalse(expression, message)`
`if (expression) throw new IlluminatorRuntimeVerificationException(message)`

### `assertEquals(expected, received, message)`
`if (expected != received) throw new IlluminatorRuntimeVerificationException(message)`

### `assertNotEquals(expected, received, message)`
`if (expected == received) throw new IlluminatorRuntimeVerificationException(message)`

### `assertMatch(regExp, expression, message)`
`if (!regExp.test(expression)) throw new IlluminatorRuntimeVerificationException(message)`

### `assertNull(expression, message)`
`if (expression !== null) throw new IlluminatorRuntimeVerificationException(message)`

### `assertNotNull(expression, message)`
`if (expression === null) throw new IlluminatorRuntimeVerificationException(message)`

### `assertWindow()`
Currently unimplemented.

### Comparing screenshots
`actionCompareScreenshotToMaster(parm)` where `parm` is an object with the following properties:

* `masterPath` - the location on disk of the expected image
* `maskPath` - the location on disk of a mask image (#FF00FF everywhere that shouldn't be compared)
* `captureTitle` - the title of the file(s) to save when running this comparison
* `allowedPixels` - the maximum number of pixels that are allowed to differ between the images (optional, default 0)
* `allowedPercent` - the maximum percentage difference (in terms of number of pixels) allowed to differe between the images (optional, default 0)


Extensions - `uiautomation-ext.js`
==================================

If you'd prefer to use your own test runner but just take advantage of the Illuminator javascript extensions (in the way that you might have taken advantage of the tuneup_js extensions), then simply add the following 2 lines to your code:

```javascript
#import "/path/to/Illuminator/gem/resources/js/Extensions.js"
IlluminatorScriptsDirectory = "/path/to/Illuminator/gem/resources/scripts";
```

Additionally, if you want to use any of the functionality provided by `simctl`, then you should define the following as well:

```javascript
config.xcodePath = "/Applications/Xcode.app/Contents/Developer";
config.targetDeviceID = "<one of the UIDs from 'simctl list'>";
config.isHardware = false; // indicate that we are on a simulator
```


UIAutomation Extensions
-----------------------

### `UIATableView.prototype.cellNamed(name)`
Unimplemented.  Use `table.cells().firstWithName(name)`.

### `UIATableView.prototype.assertCellNamed(name)`
Unimplemented.  Use `table.cells().firstWithName(name).elements()` which should throw an exception.

### `UIAElement.prototype.elementJSONDump(recursive, attributes, visibleOnly)`
Unimplemented.  Could be implemented using `.reduce()`, so get in touch if you need this.

### `UIAElement.prototype.logElementJSON(attributes)`
Unimplemented.  Get in touch if you need this.

### `UIAElement.prototype.logElementTreeJSON(attributes)`
Unimplemented.  Could be implemented using `.reduce()`, so get in touch if you need this.

### `UIAElement.prototype.logVisibleElementJSON(attributes)`
Unimplemented.  Could be implemented using `.reduce()`, so get in touch if you need this.

### `UIAElement.prototype.logVisibleElementTreeJSON(attributes)`
Unimplemented.  Could be implemented using `.reduce()`, so get in touch if you need this.

### `UIAElement.prototype.waitUntilVisible(timeout)`
Use `element.waitForVisibility(timeout, true)`

### `UIAElement.prototype.waitUntilInisible(timeout)`
Use `element.waitForVisibility(timeout, false)`

### `UIAElement.prototype.waitUntilFoundByName(name, timeout)`
Use the following:

```javascript
element.waitForChildExistence(timeout, true, name, function (e) { return e.elements()[name]; })
```

### `UIAElement.prototype.waitUntilNotFoundByName(name, timeout)`
Use the following:

```javascript
element.waitForChildExistence(timeout, false, name, function (e) { return e.elements()[name]; })
```

### `UIAElement.prototype.waitUntilAccessorSuccess(f, timeout, label)`
`element.waitForChildExistence(timeout, true, label, f)`

### `UIAElement.prototype.waitUntil(filter, condition, timeout, description)`
Unimplemented.

### `UIAElement.prototype.waitUntilHasName(name, timeout)`
`element.waitForName(timeout, name)`

### `UIAElement.prototype.vtap(timeout)`
Exists as-is.

### `UIAElement.prototype.svtap(timeout)`
Exists as-is.

### `UIAElement.prototype.tapAndWaitForInvalid(timeout)`
Use the following:

```javascript
element.tap();
element.waitForValidity(timeout, false);
```

### `UIAElement.prototype.equals(other)`
Exists as-is (we contributed this).

### `UIAElement.prototype.captureWithName(name)`
`element.captureImage(name)`

### `UIAElementNil.prototype.isNotNil()`
Exists as-is (we contributed this).

### `UIAElementNil.prototype.isValid()`
Exists as-is

### `UIAElementNil.prototype.isVisible()`
Exists as-is

### `UIAElementArray.prototype.withNameRegex(pattern)`
Exists as-is (we contributed this).

### `UIAElementArray.prototype.firstWithNameRegex(pattern)`
Exists as-is (we contributed this).

### `UIAApplication.prototype.navigationTitle()`
Unimplemented.

### `UIAApplication.prototype.isPortraitOrientation()`
Unimplemented.

### `UIAApplication.prototype.isLandscapeOrientation()`
Unimplemented.

### `UIANavigationBar.prototype.assertLeftButtonNamed(name)`
Unimplemented.

### `UIANavigationBar.prototype.assertRightButtonNamed(name)`
Unimplemented.

### `UIATarget.prototype.isPortraitOrientation()`
Unimplemented.

### `UIATarget.prototype.isLandscapeOrientation()`
Unimplemented.

### `UIATarget.prototype.isSimulator()`
`!config.isHardware`

### `UIATarget.prototype.isDeviceiPad()`
Unimplemented.  This could be added via a `simctl` command, so get in touch if you need it.

### `UIATarget.prototype.isDeviceiPhone()`
Unimplemented.  This could be added via a `simctl` command, so get in touch if you need it.

### `UIATarget.prototype.isDeviceiPhone5()`
Unimplemented.  This could be added via a `simctl` command, so get in touch if you need it.

### `UIATarget.prototype.captureAppScreenWithName(imageName)`
Provided by Apple.

### `UIATarget.prototype.logDeviceInfo()`
Unimplemented.

### `UIAKeyboard.prototype.keyboardType()`
Unimplemented.

### `UIAKeyboard.prototype.typeString(string)`
Provided by Apple.

### `UIATextField.prototype.typeString(string)`
Exists as-is.

### `UIATextField.prototype.clear()`
Exists as-is.

### `UIATextView.prototype.typeString(string)`
Exists as-is.

### `UIATextView.prototype.clear()`
Exists as-is.


Javascript Extensions
---------------------

### `extend(destination, source)`
You probably want `extendPrototype(baseClass, propertiesObject)`.

### `dumpProperties(object)`
Unimplemented.  Use `for (var k in object) if (typeof(object[k]) === "function")`.

### `getMethods(object)`
Unimplemented.  Use `for (var k in object) if (typeof(object[k]) !== "function")`.

### `reduce(callback, initialValue)`
Exists as-is (we contributed this).

### `find(criteria, varName)`
Exists as-is (we contributed this).

### `elementAccessorDump(varName)`
Exists as-is (we contributed this).

### `waitUntilAccessorSelect(lookupFunctions, timeoutInSeconds)`
`element.waitForChildSelect(timeoutInSeconds, lookupFunctions)` (we contributed this).

### `checkIsEditable()`
Exists as-is (we contributed this).

### `Array.prototype.contains(f)`
Unimplemented.

### `Array.prototype.unique()`
Unimplemented.

### `String.prototype.trim()`
Unimplemented.

### `String.prototype.ltrim()`
Unimplemented.

### `String.prototype.rtrim()`
Unimplemented.

### `String.prototype.lcfirst()`
Unimplemented.