Element Selectors in Illuminator
--------------------------------

One of the main innovations in Illuminator is the way that elements can be accessed: **selector**s.  Assume you have a root element `mainWindow`:

```javascript
var mainWindow = UIATarget.localTarget().frontMostApp().mainWindow();
```

Normally in UIAutomation, to access a screen element you must access it by direct reference:

```javascript
var myButton = mainWindow.tableViews()["My table"].cells()["My cell"]buttons()["My button"];
```

A common problem in UIAutomation is that referring to an element in this way can leave you with a `UIAElementNil` if your desired element has not yet been placed on the screen.  To allow for this, Illuminator uses a **selector** to indirectly refer to a given screen element; selectors can be passed as data, and evaluated repeatedly until the element to which they refer becomes available.

There are 4 types of selectors in Illuminator, all working relative to a parent element.  2 are "Hard" selectors, and 2 are "soft" selectors.  Hard selectors make direct reference to one and only one element, while soft selectors describe general descriptions that may refer to several distinct elements at once.

#### 1. Lookup functions (hard selectors)

A lookup function takes the parent element as an argument and returns a child element.  In the `"My button"` example, it would look like the following:

```javascript
var mySelector = function (myMainWindow) {
    return myMainWindow.tableViews()["My table"].cells()["My cell"]buttons()["My button"];
};
var myButton = mainWindow.getChildElement(mySelector);
```

Lookup functions are the fastest type of selector, and will return one and only one element (`UIAElementNil` or otherwise).

Note
> Lookup functions are designed to work relative to a specific element (in this case, `mainWindow`).


#### 2. Strings (hard selectors)

A string selector provides comparable speed to a lookup function, but without the extra syntax required to write a function.  The string is `eval`'d, with the parent element in the scope as `element`.

```javascript
var mySelector = 'element.tableViews()["My table"].cells()["My cell"]buttons()["My button"]';
var myButton = mainWindow.getChildElement(mySelector);
```

Whether the use of `eval` is good programming practice is beyond the scope of this document.


#### 3. Criteria (soft selectors)

A criteria selector is a javascript object containing values that will be matched against each element in the tree beneath the parent element.

> Note: due to extremely poor performance in UIAutomation's javascript performance in iOS 8.x (5ms to evaluate some object methods instead of ~0ms), the future reliability of soft selectors is threatened (by Apple).  As a compromise, iOS 8 searches are done using only the `.elements()` array instead of element-specific lookups.

```javascript
var mySelector = {name: "My button", UIAType: "UIAButton"};
var myButton = mainWindow.getChildElement(mySelector);
```

The following criteria fields are accepted:

* `UIAType`, matching the class name of the UIAElement
* `nameRegex`, a regular expression that will be applied to the `name()` method
* One of the following property names matching the actual value of that property:
    * `rect`
    * `hasKeyboardFocus`
    * `isEnabled`
    * `isValid`
    * `isVisible`
    * `label`
    * `name`
    * `value`

Criteria selectors can be much slower than lookup functions or string selectors (0.2-0.7 seconds is typical, depending on how many elements are in the tree), but have the advantage of being resilient to any changes in the app's element hierarchy.

Unlike lookup functions or strings, selectors can return multiple elements, or none.   Because of the relatively costly access time, Illuminator logs to the console the direct references to any elements found by evaluating a selector.


#### 4. Criteria Arrays (soft selectors)

To help constrain the number of elements returned by a critera selector (in cases where there may be several matches), criteria can be chained together in array form.  This can be an expensive operation, as all elements returned by the first selector in the array will be used as parent elements for the second selector in the array, and so on.

```javascript
var mySelector = [{name: "My table", UIAType: "UIATableView"},
                  {name: "My cell", UIAType: "UIATableCell"},
                  {name: "My button", UIAType: "UIAButton"}];
var myButton = mainWindow.getChildElement(mySelector);
```

Extending Selectors - an Example
------------------------------------

For convenience, it's possible to extend the set of fields that a criteria selector can respond to.  This is done by overriding the `UIAElement`'s prototype `preProcessSelector` function with a user-supplied function.  The function should take a criteria object (or array of criteria objects), and map any custom fields into the known fields described above.

This trivial preprocessor example intercepts a custom field -- a currency `amount` specified as a float -- and converts it to a condition on the `name` field.

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
    // iterate over the selectors in the chain
    for (var i = 0; i < selector.length; ++i) {
        // iterate over the fields in one criteria selector and build the modified criteria
        var criteria = {};
        for (var k in selector[i]) {
            // keep all fields the same, but if we encounter "amount" then convert it
            var v = selector[i][k];
            if (key == "amount") {
                criteria["name"] = "$" + v.toFixed(2);
            } else {
                criteria[k] = v;
            }
        }
        outputSelector.push(criteria);
    }
    return outputSelector;
}
// immediately place this function inside prototype
UIAElement.prototype["preProcessSelector"] = preProcessSelectorWithCurrency;
```