#import "../Common.js";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
var ab = appmap.actionBuilder.makeAction;
appmap.createOrAugmentApp("SampleApp").withScreen("bridge")
    .onTarget("iPhone", function () { return true; }) // the screen is always "active"

    .withAction("resetToHomeScreen", "forcibly return the app to the home screen in an initial state")
    .withImplementation(bridge.makeActionFunction("resetToMainMenu"));
