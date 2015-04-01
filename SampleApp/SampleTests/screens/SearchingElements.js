#import "../Common.js";

function actionSearchingElementsBack() {
    mainWindow().navigationBars()["Searching For Elements"].buttons()["Back"].tap();
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Appmap additions
////////////////////////////////////////////////////////////////////////////////////////////////////
var ab = appmap.actionBuilder.makeAction;
appmap.createOrAugmentApp("SampleApp").withScreen("searchingElements")
    .onTarget("iPhone", ab.screenIsActive.byElement("searchingElements",                                           // the screen name (for logging)
                                                    "searching for elements screen",                               // what we are looking for (for logging)
                                                    {name: "Searching For Elements", UIAType: "UIANavigationBar"}, // selector to use
                                                    10))                                                           // timeout



    .withAction("back", "Go back from the element search screen")
    .withImplementation(actionSearchingElementsBack);
