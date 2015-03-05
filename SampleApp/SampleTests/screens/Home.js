#import "../Common.js";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
var ab = appmap.actionBuilder.makeAction;
appmap.createOrAugmentApp("SampleApp").withScreen("homeScreen")
    .onTarget("iPhone", ab.screenIsActive.byElement("homeScreen",
                                                    "Automator Sample App",
                                                    {name: "Illuminator Sample", UIAType: "UIAStaticText"},
                                                    10))

    .withAction("crash", "Crash the app")
    .withImplementation(ab.element.tap({name: "Crash The App", UIAType: "UIAStaticText"}), "iPhone")

    .withAction("openSearch", "Open the element search screen")
    .withImplementation(ab.element.tap({name: "", UIAType: "UIAStaticText"}), "iPhone")

    .withAction("openWait", "Open the wait-for-me screen")
    .withImplementation(ab.element.tap({name: "", UIAType: "UIAStaticText"}), "iPhone")

    .withAction("openCustomKeyboard", "Open the custom keyboard screen")
    .withImplementation(ab.element.tap({name: "", UIAType: "UIAStaticText"}), "iPhone")
