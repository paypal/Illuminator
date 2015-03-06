#import "../Common.js";

var ab = appmap.actionBuilder.makeAction;


// this is the function we will use as the implementation of a screen action below
function actionVerifyDelayedMessage(parameters) {
    // selector function for the message we are looking for.  It will be evalauated relative to target(), so that's the argument
    var messageSelector = function(myTarget) {
        return myTarget.frontMostApp().mainWindow().staticTexts()[1];
    }

    // note that the following could all be replaced by ab.verifyElement.visibility(messageSelector, "Delayed message")(parameters)
    // it's coded here for illustrative purposes
    var message = newUIAElementNil();
    try {
        message = target().waitForChildExistence(0.5, true, "Delayed message", messageSelector);
    } catch (e) {
        if (parameters.expected) {
            throw new IlluminatorRuntimeVerificationException("The delayed message didn't match the expected state");
        }
    }
    if ((message.isNotNil() && message.isVisible()) != parameters.expected) {
        throw new IlluminatorRuntimeVerificationException("The delayed message didn't match the expected state");
    }

    // optionally test the text of the message
    if (parameters.text !== undefined && message.name() != parameters.text) {
        throw new IlluminatorRuntimeVerificationException("The delayed message didn't have the expected text");
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
appmap.createOrAugmentApp("SampleApp").withScreen("waitForMe")
    .onTarget("iPhone", ab.screenIsActive.byElement("waitForMe",
                                                    "Wait For Me screen",
                                                    {name: "Wait For Elements", UIAType: "UIAStaticText"},  // the navbar title indicates we are on this screen
                                                    10))

    .withAction("verifyDelayedMessage", "Evaluate whether the delayed message is shown as expected")
    .withImplementation(actionVerifyDelayedMessage, "iPhone")
    .withParam("expected", "Whether the message is expected to be shown (boolean)", true, true)   // true, true : required, value will be logged
    .withParam("text", "The expected text of the message (string)", false, true);                 // false, true: optional, value will be logged
