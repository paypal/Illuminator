#import "../Common.js";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
var ab = appmap.actionBuilder.makeAction;
appmap.createOrAugmentApp("SampleApp").withScreen("homeScreen")
    .onTarget("iPhone", ab.screenIsActive.byElement("homeScreen",                                           // the screen name (for logging)
                                                    "Illuminator Sample App home screen",                   // what we are looking for (for logging)
                                                    {name: "Illuminator Sample", UIAType: "UIAStaticText"}, // selector to use
                                                    10))                                                    // timeout

    .withAction("crash", "Crash the app")
    .withImplementation(ab.element.tap({name: "Crash The App", UIAType: "UIAStaticText"}), "iPhone")

    .withAction("openSearch", "Open the element search screen")
    .withImplementation(ab.element.tap({name: "Searching Elements", UIAType: "UIAStaticText"}), "iPhone")

    .withAction("openWait", "Open the wait-for-me screen")
    .withImplementation(ab.element.tap({name: "Wait For Me", UIAType: "UIAStaticText"}), "iPhone")

    .withAction("openCustomKeyboard", "Open the custom keyboard screen")
    .withImplementation(ab.element.tap({name: "Custom Keyboard", UIAType: "UIAStaticText"}), "iPhone")
