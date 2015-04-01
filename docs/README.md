ILLUMINATOR Quick Start Guide
=============================

This is the minimal crash course you need to get started writing and executing Illuminator test scenarios.

### The Basics
* The **[AppMap](AppMap.md)** defines the functionality of an iOS App
    * An **app** has **screen**s that are available on certain **target**s
    * A **screen** has a function to verify whether it is active, and **action**s
    * An **action** has a set of **parameter**s and a mapping of **target**s to **implementation**s
* The **[Automator](Automator.md)** defines **test scenario**s
    * A test scenario has a **name**, some **tag**s, and a series of **step**s
    * A step is an **action**, possibly with some **parameter**s
* The [command line scripts](Commandline.md) provide the entry point to testing
	* Building the executable
	* Loading the binary into the target execution environment
	* Running the desired set of **test scenario**s, by **name** or by **tag**, for a desired **implementation**
* The **[Bridge](Bridge.md)** enables RPC functionality between the AppMap, Automator, and your app


Minimal Example
---------------

In this example, we assume that an app has only two screens: a login screen (username field, password field, and login button), and a welcome screen (with static text "Welcome *username*" and a logout button).

```javascript
/* Example.js */

var ab = appmap.actionBuilder.makeAction;  // shortcut name to action builder -- it builds action functions

function actionEnterCredentials(param) {
    mainWindow().getOneChildElement({name: "username", UIAType: "UIATextField"}).typeString(param.username);
    mainWindow().getOneChildElement({name: "password", UIAType: "UIATextField"}).typeString(param.password);
}

function actionVerifyUsername(param) {
	// attempt to access the element with the given name; will throw exception if not found
	mainWindow().getOneChildElement({name: "Welcome " + parm.username, UIAType: "UIATextField"});
}

// describe the login screen and possible interactions
appmap.createOrAugmentApp("MyTinyApp").withScreen("login")
    .onTarget("MyIphone", ab.screenIsActive.byElement("login", "login button",  // the screen and element
                                                    {name: "Log In", UIAType: "UIAButton"},  // selector
                                                    10))  // timeout for screen to become active

    .withAction("enterCredentials", "Enter username and password")
    .withImplementation(actionEnterCredentials)   // reference to function defined above.
    .withParam("username", "The username", true)  // note that these parameters match the
    .withParam("password", "The password", true)  // fields referenced in the "param" argument

    .withAction("authenticate", "Tap the login button")
    .withImplementation(ab.element.tap({name: "Log In", UIAType: "UIAButton"}, "login button"));


// describe the welcome screen and possible interactions
appmap.createOrAugmentApp("MyTinyApp").withScreen("welcome")
    .onTarget("MyIphone", ab.screenIsActive.byElement("welcome", "logout button",
                                                    {name: "Log Out", UIAType: "UIAButton"},
                                                    10))

    .withAction("verifyUsername", "Verify that the proper username is shown on the screen")
    .withImplementation(actionVerifyUsername)     // reference to function defined above.
    .withParam("username", "The username", true);

    .withAction("logout", "Tap the logout button")
    .withImplementation(ab.element.tap({name: "Log Out", UIAType: "UIAButton"}, "logout button"));


// create our first tests
var mta = appmap.apps("MyTinyApp");  // shortcut to app name

automator.createScenario("Valid user logs in and is welcomed", ["myTestTag", "login", "happyPath"])
    .withStep(mta.login.enterCredentials, {username: "pat", password: "1234"})
    .withStep(mta.login.authenticate)
    .withStep(mta.welcome.verifyUsername, {username: "pat"})
    .withStep(mta.welcome.logout)
    .withStep(mta.login.verityIsActive);  // note that we didn't define verifyIsActive; it's built-in

automator.createScenario("Bad password doesn't get to welcome screen", ["myTestTag", "login", "errorPath"])
    .withStep(mta.login.enterCredentials, {username: "pat", password: "4321"})  // bad password
    .withStep(mta.login.authenticate)
    .withStep(mta.welcome.verifyNotActive);  // note that we didn't define verifyNotActive; it's built-in
```

A script is available to run integration test files from the command line: `automationTests.rb`.

Example usage of the `Example.js` file above:
```
$ ruby ./scripts/automationTests.rb -p /path/to/Example.js -a MyTinyApp -s MyTinyApp -i MyIphone -t myTestTag
```


This should launch an instance of the simulator (possibly requiring credentials from OSX) and
then run the test script, outputting the log to the terminal.



Wait, But Where Do You Import Illuminator Into Your Javascript Code?
--------------------------------------------------------------------

You don't. The Illuminator [command line scripts](Commandline.md) handle this for you, as well as a host of other amazing features.



Further Documentation
---------------------
* [Slow start guide - practical introduction](PracticalIntroduction.md)
* [Selecting elements](Selectors.md)
* [Working with elements](Extensions.md)
* [Defining screens](AppMap.md)
* [Writing tests](Automator.md)
* [Running tests via the command line with Ruby scripts](Commandline.md)
* [The RPC channel](Bridge.md)
* [Troubleshooting](Troubleshooting.md)
