require 'optparse'
require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationConfig.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationArgumentParser.rb')


parser = AutomationArgumentParser.new

options = {}
####################################################################################################
# setupDefaults
####################################################################################################

options["workspace"] = Dir.pwd

options["defaultXcode"] = '/Applications/Xcode.app'
options["plistSettingsPath"] = ""
options["implementation"] = "iPhone"


options["report"] = FALSE
options["verbose"] = FALSE

options["tagsAny"] = nil
options["tagsAll"] = nil
options["tagsNone"] = nil

options["randomSeed"] = nil

options["skipBuild"] = FALSE
options["doKillAfter"] = TRUE
options["coverage"] = FALSE


options["hardwareID"] = nil
options["appName"] = ""
options["testPath"] = ""


options["simDevice"] = 'iPhone Retina (4-inch)'
options["simVersion"] = 'iOS 7.0'
options["simLanguage"] = 'en'

options["timeout"] = 30


options = options.merge(parser.parse ARGV)


Dir.chdir(File.dirname(__FILE__) + "/../")

####################################################################################################
# Storing parameters
####################################################################################################


tagsAny_arr = Array.new(0)

tagsAny_arr = options["tagsAny"].split(',') unless options["tagsAny"].nil?

tagsAll_arr = Array.new(0)
tagsAll_arr = options["tagsAll"].split(',') unless options["tagsAll"].nil?

tagsNone_arr = Array.new(0)
tagsNone_arr = options["tagsNone"].split(',') unless options["tagsNone"].nil?



config = AutomationConfig.new(options["implementation"],
                                  options["testPath"])

unless options["hardwareID"].nil?
  config.setHardwareID options["hardwareID"]
else
  config.setSimVersion options["simVersion"]
end

unless options["plistSettingsPath"].nil?
  config.setCustomConfig options["plistSettingsPath"]
end

unless options["randomSeed"].nil?
  config.setRandomSeed options["randomSeed"]
end
config.defineTags tagsAny_arr, tagsAll_arr, tagsNone_arr



####################################################################################################
# Script action
####################################################################################################


unless options["skipBuild"]
  builder = AutomationBuilder.new()
  builder.buildScheme(options["scheme"], options["hardwareID"], options["workspace"])

end

runner = AutomationRunner.new(options["defaultXcode"],
                              options["scheme"],
                              options["appName"])

if !options["hardwareID"].nil?
  runner.setHardwareID options["hardwareID"]
elsif !options["skipSetSim"]
  runner.setupForSimulator options["simDevice"], options["simVersion"], options["simLanguage"]
end

config.save() # must save AFTER automationRunner initializes
runner.runAllTests(options["report"], !options["skipKillAfter"], options["verbose"], options["timeout"])
