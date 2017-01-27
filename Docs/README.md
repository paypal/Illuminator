# Illuminator TL;DR Manual

1. Copy the `HomeScreen.swift`, `ExampleTestApp.swift`, and `IlluminatorTestCase.swift` files from the example app.
2. Record some element interactions using XCUITest against your app
3. Copy those element interactions into new screen actions as appropriate
4. Remove any anti-patterns as specified in this guide
5. Set breakpoints where it says "(set breakpoint here)"
6. Script your actions together using this basic skeleton:

```swift

func testUsingIlluminatorForTheFirstTime() {
    // these 2 lines should go in the setUp() method for your test class, 
    // or better yet: the IlluminatorTestCase class
    let interface = ExampleTestApp(testCase: self)
    let initialState = IlluminatorTestProgress<AppTestState>.Passing(AppTestState(didSomething: false))
        
    initialState                                  // The initial state is "passing"
        .apply(interface.home.enterText("123"))   // to which we apply an action
        .apply(interface.home.verifyText("123"))  // and another action
        .finish(self)                             // then finalize & handle the result

}

```

7. Run tests and see what happens.  Send complaints about this documentation.


#Illuminator Anti-Patterns and How to Fix Them

You don't have to do any of these things, because Illuminator is completely compatible with the XCTest paradigm.  (You can even mix & match Illuminator actions with your own XCUITest code, if you need to migrate slowly.)  But, you'll get the full benefits of Illuminator if you follow these guidelines.


## Anything `XCT___` Related, Like `XCTAssert` or `XCTFail`

These functions are test cancer -- they prematurely terminate the life of a test before it can tell you anything useful.  All you get is a note on how it died.  Depressing, right?  Right.  Avoid them.

### What to Use Instead

Throw exceptions within your actions -- they will automatically be caught and, later, interpreted as a test failure in the `.finish()` method.

For general purpose comparisons, throw `IlluminatorExceptions.VerificationFailed`.

```swift
XCTAssertEqual(app.allElementsBoundByAccessibilityElement.count, 3)   // Bad

guard app.allElementsBoundByAccessibilityElement.count == 3 else {    // 
    throw IlluminatorExceptions.VerificationFailed(message: "!= 3")   // Good
}                                                                     // (In practice, wrap it to make a one-liner)
```


For element-centric assertions, use `.assertProperty()` to check any property of an XCUIElement.

```swift
XCTAssert(myElement.exists)                       // Bad

try myElement.assertProperty(true) { $0.exists }  // Good
```


If your concern is only that an element is ready for interactions (it exists and is hittable), use `.ready()`.

```swift
XCTAssert(myElement.hittable) // Bad
myElement.tap()               //

try myElement.ready().tap()   // Good
```


## Anything Async, Like `expectationForPredicate` or `waitForExpectationsWithTimeout`

Async would be great if it resulted in exceptions instead of test failures, but as of this writing it doesn't.  Generally, the need for these functions implies that the app is busy doing something that you need to wait for.  Illuminator is, at its core, designed to wait patiently.  


### What to Use Instead

Consider this example where we need to wait for the existence of an element to tap it.

```swift
let exists = NSPredicate(format: "exists == 1")                      //
expectationForPredicate(exists, evaluatedWithObject: myElement) {    // Bad
    myElement.tap()                                                  //
    return true                                                      //
}                                                                    //
waitForExpectationsWithTimeout(5, handler: nil)                      //

try myElement.waitForProperty(5, desired: true) { $0.exists }        // Good
myElement.tap()                                                      // (you can even chain these calls)
```
 
 
## Anything Like `sleep()` or Delaying

Sleeping is a naive way of waiting for some UI change to happen.  It's better to simply watch for the change and move on as soon as it happens.  There are 2 anti-patterns here, one within a screen and one between screens.


### What to Use Instead

Within the same screen, consider this example where tapping `myButton` causes `someOtherButton` to become visible, after several seconds.

```swift
myButton.tap()                          //
sleep(3)                                // Bad 
someOtherButton.tap()                   // 

myButton.tap()                          //
try someOtherButton.whenReady(3).tap()  // Good
```

For uses of sleep between screens, see the "Best Practices" section instead.


## XCUIElementQuery Subscripting, Especially When it Might Be Ambiguous

If you want to tap a button called "Delete" in a table cell, and there are multiple cells each with their own "Delete" button, using XCUIElmentQuery to access the button will cause the test to automatically fail.  The dreaded `Multiple matches found` error.

This is tragic and unnecessary.  Illuminator provides functions to more safely traverse the element tree.


### What to Use Instead

Consider the situation in which multiple matches might appear, but you only ever want the first one.

```swift
// Assume that multiple "Delete" buttons exist
app.buttons["Delete"].tap()                                          // Bad

let matches = app.buttons.subscriptsMatching("Delete")               //
guard let myButton = matches[safe: 0] else {                         //
    throw IlluminatorExceptions.VerificationFailed(message: "None")  // Good
}                                                                    //
myButton.tap()                                                       //

let matches = app.buttons〚"Delete"〛                                 // Experimental unicode operator
```

Or, perhaps you expect one and only one match.  Illuminator has an operator for that as well.

```swift
// Assume that multiple "Delete" buttons might exist, but shouldn't
app.buttons["Delete"].tap()                     // Bad

try app.buttons.hardSubscript("Delete").tap()   // Good

try app.buttons⁅"Delete"⁆.tap()                 // Experimental unicode operator
```
