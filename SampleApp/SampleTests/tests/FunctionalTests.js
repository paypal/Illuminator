#import "../Common.js";

var ia = appmap.apps["Illuminator"];  // shortcut reference to built-in Illuminator test steps
var app = appmap.apps["SampleApp"];   // shortcut reference to sample app test steps

automator.createScenario("Wait for an element to appear", ["functional", "smoke", "wait"])
    .withStep(app.homeScreen.openWait)
    .withStep(app.waitForMe.verifyDelayedMessage, {expected: false})
    .withStep(ia.do.delay, {seconds: 5})
    .withStep(app.waitForMe.verifyDelayedMessage, {expected: true, text: "Thanks for waiting"});
