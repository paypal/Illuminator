Extensions.js Reference
=======================

Illuminator extends many of the UIAElement types provided by [Apple's UIAutomation system](https://developer.apple.com/library/ios/documentation/DeveloperTools/Reference/UIAutomationRef/_index.html).


Element Selectors in Illuminator
--------------------------------

One of the main innovations in Illuminator is the way that elements can be accessed: **selector**s.  Assume you have a root element `mainWindow`:

```javascript
var mainWindow = UIATarget.localTarget().frontMostApp().mainWindow();
```

Normally in UIAutomation, to access a screen element you must access it by direct reference:

```javascript
mainWindow.tableViews()["My table"].cells()["My cell"]buttons()["My button"];
```

A common problem in UIAutomation is that referring to an element in this way can leave you with a `UIAElementNil` if your desired element has not yet been placed on the screen.  To allow for this, Illuminator uses a **selector** to indirectly refer to a given screen element; selectors can be passed as data, and evaluated repeatedly until the element to which they refer becomes available.

There are 4 types of selectors in Illuminator, all working relative to a parent element, e.g.:

```javascript
mainWindow.getChildElement(mySelector);
```


#### 1. Lookup functions

A lookup function takes the parent element as an argument and returns a child element.  In the `"My button"` example, it would look like the following:

```javascript
var mySelector = function (myMainWindow) {
    return myMainWindow.tableViews()["My table"].cells()["My cell"]buttons()["My button"];
};
```

Lookup functions are the fastest type of selector, and will return one and only one element (`UIAElementNil` or otherwise).


#### 2. Strings

A string selector provides comparable speed to a lookup function, but without the extra syntax required to write a function.  The string is `eval`'d, with the parent element in the scope as `element`.

```javascript
var mySelector = 'element.tableViews()["My table"].cells()["My cell"]buttons()["My button"]';
```

Whether the use of `eval` is good programming practice is beyond the scope of this document.


#### 3. Criteria

A criteria selector is a javascript object containing values that will be matched against each element in the tree beneath the parent element.  These criteria fields are the same as those in the `.find()` function described elsewhere in this document.

```javascript
var mySelector = {name: "My button", UIAType: "UIAButton"};
```

Criteria selectors can be much slower than lookup functions or string selectors (0.2-0.7 seconds is typical, depending on how many elements are in the tree), but have the advantage of being resilient to any changes in the app's element hierarchy.

Unlike lookup functions or strings, selectors can return multiple elements, or none.   Because of the relatively costly access time, Illuminator logs to the console the direct references to any elements found by evaluating a selector.


#### 4. Criteria Array

To help constrain the number of elements returned by a critera selector (in cases where there may be several matches), criteria can be chained together in array form.  This can be an expensive operation, as all elements returned by the first selector in the array will be used as parent elements for the second selector in the array, and so on.

```javascript
var mySelector = [{name: "My table", UIAType: "UIATableView"},
                  {name: "My cell", UIAType: "UIATableCell"},
                  {name: "My button", UIAType: "UIAButton"}];
```

General Purpose Functions Reference
-----------------------------------

#### `target()`
Returns a fresh reference to `UIATarget.localTarget()`.

#### `mainWindow()`
Returns a fresh reference to `UIATarget.localTarget().frontMostApp().mainWindow()`.

#### `delay()`
Shortcut to `UIATarget.localTarget().delay()`.

#### `getTime()`
Returns the number of seconds (with decimal milliseconds) since Jan 1st, 1970.

#### `isNotNilElement(elem)`
Returns `true` if the given element is a valid non-nil `UIAElement`.

### `isHardSelector(selector)`
Returns `true` if the given selector is a lookup function or string -- returning at most only one element.

### `newUIAElementNil()`
Returns what you'd expect `new UIAElementNil()` to return, since it doesn't.


UIAElement Method Extensions Reference
--------------------------------

This is a function reference, not a class reference; the classes to which these functions belong will be indicated.

#### `.checkIsEditable()` - UIAElement
Tap the element and return true if a keyboard is displayed.

#### `.checkIsPickable()` - UIAElement
Tap the element and return true if a set of picker wheels is displayed.

#### `.clear()` - UIATextField, UIATextView
Clear the text in the text field.

#### `.elementReferenceDump(varName, visibleOnly)` - UIAElement
Logs the output of `.getChildElementReferences` to the console.

#### `.equals(element, maxRecursion)` - UIAElement
Returns `true` if this element equals `element` -- they (and all ancestors) have the same `name()`, type, `isVisible()`, and `rect()`.  Note that this function is not necessarily immune to false positives, although they are highly unlikely to exist.

#### `.find(criteria, varName)` - UIAElement
Finds any element in the tree beneath this element that matches the `criteria`.  Returns an associative array of elements, keyed off their string selectors (which will begin with `varName`).  The following criteria fields are accepted:

* `UIAType`, matching the class name of the UIAElement
* `nameRegex`, a regular expression that will be applied to the name() method
* One of the following property names matching the actual value of that property:
    * `rect`
    * `hasKeyboardFocus`
    * `isEnabled`
    * `isValid`
    * `isVisible`
    * `label`
    * `name`
    * `value`

For example, a valid criteria object might look like the following:

```javascript
{isVisible: true, name: "My Element", UIAType: "UIAStaticText"}
```

#### `.firstWithNameRegex(pattern)` - UIAElementArray
Same as `.firstWithName(name)` for UIAElementArray objects, but does a regular expression match.

#### `.getCellWithPredicateByScrolling(cellPredicate)` - UIATableView
Given a valid predicate (for `.firstWithPredicate`), scroll through the UIATableView until a matching cell is found.  This is necessary in cases where content is dynamically loaded, because the `.name()` property is not always available for cells in table views.

#### `.getChildElement(selector)` - UIAElement
Returns the element retrieved by the given selector, relative to this element.

#### `.getChildElementReferences(varName, visibleOnly)` - UIAElement
Returns an array of strings (relative to `varName` indicating the string selector of child elements.  Optionally, `visibleOnly` controls whether to traverse hidden elements.

#### `.getChildElements(criteria)` - UIAElement
Returns an associative array of UIAElements matching the criteria selector, keyed on the string version of that element's selector.

#### `.getOneChildElement(selector)` - UIAElement
Returns one non-nil UIAElement specified by the selector; throws an exception if 0 or multiple elements are returned.

#### `.isNotNil()` - UIAElement, UIAElementNil
Returns true if the element is not `UIAElementNil`.

#### `.isVisible()` - UIAElementNil
Similar to `.isVisible()` for ordinary UIAElement objects but always returns false.  Provided for compatibility.

#### `.pickDate(year, month, day)` - UIATextField, UIATextView, UIAStaticText
If the date picker wheels are not visible, taps the element.  Picks the year, month, and day.

#### `.preProcessSelector(selector)` - UIAElement
This is a prototype function that can be replaced with an app-specific preprocessing function.  It intercepts selectors before they are passed to any selector evaluation function, allowing new functionality or criteria to be understood.

#### `.reduce(callback, initialValue)` - UIAElement
Applies a callback function to every element in the tree.  The callback must accept the following arguments:

1. `initialValue` first, then whatever was returned by the last invocation of the callback function
2. The UIAElement currently being visited
3. The string selector to the element being visited
4. The UIAElement on which `.reduce` was originally called


#### `.reduceVisible(callback, initialValue)` - UIAElement
Same as `.reduce`, but applies only to visible elements.

#### `.svtap(timeout)` - UIAElement
Attempt to `.scrollToVisible` on the element before `.vtap`ing it.

#### `.typeString(text, clear)` - UIATextField, UIATextView
If the keyboard is not visible, taps the element.  If `clear` is `true`, deletes all the text in the box.  Next, attempts to type the value of `text` on the keyboard.  Handles strange exceptions in iOS 6.x related to keys not being tappable, and other random errors related to tapping keys too quickly.

#### `.vtap(timeout)` - UIAElement
Wait `timeout` seconds for the element to become visible.  If it does, tap it; if not, throw an exception.

#### `.waitForChildExistence(timeout, existenceState, description, selector)` - UIAElement
Wait for a `selector` called `description` from this element to return an element (or not, as defined in `existenceState`) in the given `timeout`.  If `existenceState` is `true`, a non-nil element will be returned (or an exception thrown).  If `false`, a `UIAElementNil` will be returned for success and an exception will be thrown for failure.

#### `.waitForChildSelect(timeout, selectors)` - UIAElement
Wait `timeout` seconds for any members of an associative array of `selectors` (keyed by an arbitrary label) to return a valid element.  Elements are returned in an associative array keyed by the same arbitrary labels, or else an exception is thrown.

#### `.waitForDeviceOrientation(timeout, orientation)` - UIATarget
Wait `timeout` seconds for the orientation to equal `orientation` (e.g. `UIA_DEVICE_ORIENTATION_PORTRAIT`)

#### `.waitForInterfaceOrientation(timeout, orientation)` - UIAApplication
Wait `timeout` seconds for the orientation to equal `orientation` (e.g. `UIA_DEVICE_ORIENTATION_PORTRAIT`)

#### `.waitForLandscapetOrientation(timeout)` - UIAApplication, UIATarget
Wait `timeout` seconds for the interface orientation to be left or right landscape.

#### `.waitForName(timeout, name)` - UIAElement
Wait `timeout` seconds for `.name()` on this element to be equal to `name`.

#### `.waitForPortraitOrientation(timeout)` - UIAApplication, UIATarget
Wait `timeout` seconds for the interface orientation to be vertical (upside down counts).

#### `.waitForValidity(timeout, validity)` - UIAElement
Wait `timeout` seconds for `.isValid()` on this element to be equal to `validity`.

#### `.waitForVisibility(timeout, visibility)` - UIAElement
Wait `timeout` seconds for `.isVisible()` on this element to be equal to `visibility`.

#### `.withNameRegex(pattern)` - UIAElementArray
Same as `.withName(name)` for UIAElementArray objects, but does a regular expression match.



Preprocessing Selectors - an Example
------------------------------------

This trivial preprocessor example intercepts a currency amount specified as a float and converts it to a string.

```javascript
function preProcessSelectorWithCurrency(originalSelector) {
    if (isHardSelector(originalSelector)) return originalSelector;

    // simplify case by making everything an array
    var selector;
    if (originalSelector instanceof Array) {
        selector = originalSelector;
    } else {
        selector = [originalSelector];
    }

    var outputSelector = [];
    for (var i = 0; i < selector.length; ++i) {
        var criteria = {};
        for (var k in selector[i]) {
            if (k == "amount") {
                var floatVal = selector[i][k];
                criteria["name"] = "$" + floatVal.toFixed(2);
            } else {
                criteria[k] = selector[i][k];
            }
        }
        outputSelector.push(criteria);
    }
    return outputSelector;
}
// immediately place this function inside prototype
UIAElement.prototype["preProcessSelector"] = preProcessSelectorWithCurrency;
```
