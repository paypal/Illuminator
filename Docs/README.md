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


#Illuminator Anti-Patterns and How to Fix Them

