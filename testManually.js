#import "common/Common.js";

// do any config changes here
config.setStage("fake");
config.setDevice("iPhone");
config.setTagsAny(["smoke"]);
config.setTagsAll(["fake"]);
config.setTagsNone([]);

#import "tests/AllTests.js";

automator.logInfo();
automator.runSupportedScenarios(config.tagsAny, config.tagsAll, config.tagsNone);