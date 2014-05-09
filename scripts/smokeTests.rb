require 'pathname'
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationRunner.rb')
Dir.chdir "SampleApp/AutomatorSampleApp"
workspace = Dir.pwd

allTestPath = "../../SampleApp/SampleTests/tests/AllTests.js"
####################################################################################################
# Storing custom parameters
####################################################################################################

options = {}

options["implementation"] = 'iPhone'
options["appName"] = "AutomatorSampleApp"
options["scheme"] = "AutomatorSampleApp"
options["simVersion"] = 'iOS 7.1'
options["simDevice"] = 'iPhone Retina (4-inch)'
options["simLanguage"] = 'en'
options["tagsAny"] = 'smoke'
options["testPath"] = allTestPath
options["defaultXcode"] = '/Applications/Xcode.app'
options["timeout"] = 30
options["verbose"] = FALSE
options["report"] = TRUE
options["skipBuild"] = FALSE

AutomationRunner.runWithOptions options, workspace
