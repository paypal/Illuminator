#import "../Common.js";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
var ab = appmap.actionBuilder.makeAction;
appmap.createOrAugmentApp("SampleApp").withScreen("homeScreen")
    .onTarget("iPhone", ab.screenIsActive.byElement("homeScreen",
                                                    "Automator Sample App",
                                                    {name: "Automator Sample App", UIAType: "UIAStaticText"},
                                                    10))

    .withAction("pressButton", "Press button on screen")
    .withImplementation(ab.element.tap({name: "Press Button", UIAType: "UIAButton"}), "iPhone")

    .withAction("clearLabel", "Clear label on screen")
    .withImplementation(ab.element.tap({name: "Clear Label", UIAType: "UIAButton"}), "iPhone")

    .withAction("verifyLabelString", "Verify label has proper string")
    .withImplementation(verifyLabelString, "iPhone")
    .withParam("labelText", "label text", true, true)

    .withAction("mockLabelText", "Mock text label bridge action")
    .withImplementation(bridge.makeActionFunction("setDefaultLabelText:"), "iPhone")
    .withParam("labelText", "label text", true, true);

////////////////////////////////////////////////////////////////////////////////////////////////////
// Actions
////////////////////////////////////////////////////////////////////////////////////////////////////

function verifyLabelString(param) {
    target().waitForChildExistence(10, true, "label with text '" + param.labelText + "'", function(targ) {
        return targ.frontMostApp().mainWindow().staticTexts()[param.labelText];
    });
}
