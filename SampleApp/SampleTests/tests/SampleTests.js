#import "../Common.js";

ia = appmap.apps["Illuminator"];
app = appmap.apps["SampleApp"];

automator.createScenario("Simplest possible test", ["basic", "smoke"])
    .withStep(app.homeScreen.verifyIsActive);

automator.createScenario("Crash the app", ["crash"])
    .withStep(app.homeScreen.crash)
    .withStep(app.homeScreen.verifyNotActive);

automator.createScenario("Sample scaffold (last 2 steps) for building up automation", ["scaffolding", "smoke"])
    .withStep(ia.do.delay, {seconds: 1})
    .withStep(ia.do.logAccessors);
