

Architecture of an Automation Test Sequence
-------------------------------------------

The central component of integration testing is the `automator`.  `automator` contains a set of test scenario, each scenario tagged with some number of text tags (*e.g.* `["login", "mainsettings"]`).

Each test scenario is made of a sequence of steps, called actions.  Actions describe one possible interaction that a user may have with a given screen in the app. For example, the `orderEntry` screen has automation actions for keying in an amount to charge, and selecting a payment type.

Since actions are only valid from their host screen, a validation function is run for each action to assert that the appropriate screen is visible.  To perform no action (and only assert that the screen is visible), a default action `verifyIsActive( )` is provided in every defined screen.

Not all screens and actions are available on all devices -- differences between iPhone and iPad might mean that an action is performed in subtly different ways on each device.  Therefore, actions have implementations that are defined for each possible device.

The available apps, screens, and actions are laid out in an organizational tool called the `appmap`.  This module captures everything that the `automator` knows about the functionality of iOS targets.




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
