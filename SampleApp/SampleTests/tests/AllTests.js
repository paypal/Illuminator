#import "../Common.js";
#import "../screens/AllScreens.js";
#import "SampleTests.js";

// This is convenient place to set any & all callbacks

function printCallbackArgs(sourceName) {
    return function(parm) {
        UIALogger.logDebug(sourceName + " callback firing with args: " + JSON.stringify(parm));
    };
}

// for informational purposes, we'll just print out the parameters that each callback receives
automator.setCallbackOnInit(printCallbackArgs("onInit"));
automator.setCallbackPrepare(printCallbackArgs("prepare"));
automator.setCallbackPreScenario(printCallbackArgs("onScenarioPreScenario"));
automator.setCallbackOnScenarioPass(printCallbackArgs("onScenarioPass"));
automator.setCallbackOnScenarioFail(printCallbackArgs("onScenarioFail"));
automator.setCallbackComplete(printCallbackArgs("complete"));
