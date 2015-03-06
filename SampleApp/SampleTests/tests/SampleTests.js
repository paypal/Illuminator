#import "../Common.js";

var ia = appmap.apps["Illuminator"];  // shortcut reference to built-in Illuminator test steps
var app = appmap.apps["SampleApp"];   // shortcut reference to sample app test steps

automator.createScenario("Simplest possible test", ["basic", "smoke"])
    .withStep(app.homeScreen.verifyIsActive);

automator.createScenario("Crash the app", ["crash"])
    .withStep(app.homeScreen.crash)
    .withStep(app.homeScreen.verifyNotActive);

automator.createScenario("Sample scaffold (last 2 steps) for building up automation", ["scaffolding", "smoke"])
    .withStep(ia.do.delay, {seconds: 1})
    .withStep(ia.do.logAccessors);
