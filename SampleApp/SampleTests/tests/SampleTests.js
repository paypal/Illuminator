#import "../Common.js";

app = appmap.apps["SampleApp"];


automator.createScenario("Press button to populate label", ["tag"])
	.withStep(app.homeScreen.pressButton)
	.withStep(app.homeScreen.verifyLabelString, {labelText : "Button Pressed"})
	.withStep(app.homeScreen.clearLabel)