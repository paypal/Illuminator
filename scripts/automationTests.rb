require 'optparse'
require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationConfig.rb')



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

####################################################################################################
# parse arguments
####################################################################################################

OptionParser.new do |opts|
  opts.banner = "Usage from workspace directory: ruby {pathTo UI-Automator}/scripts/automationTests.rb [options]"
  opts.separator "######################################################################"
  opts.on("-x", "--xcode PATH", "Sets path to default Xcode instalation ") do |path|
    options["defaultXcode"] = path
  end
  opts.on("-p", "--testPath PATH", "Path to js file with all tests imported") do |path|
    options["testPath"] = (Pathname.new path).realpath().to_s
  end
  opts.on("-a", "--appName APPNAME", "App name to run") do |v|
    options["appName"] = v
  end
  opts.on("-t", "--tags-any TAGSANY", "Run tests with any of the given tags") do |v|
    options["tagsAny"] = v
  end
  opts.on("-o", "--tags-all TAGSALL", "Run tests with all of the given tags") do |v|
    options["tagsAll"] = v
  end
  opts.on("-n", "--tags-none TAGSNONE", "Run tests with none of the given tags") do |v|
    options["tagsNone"] = v
  end
  opts.on("-s", "--scheme SCHEME", "Build and run specific tests on given workspace scheme") do |v|
    options["scheme"] = v
  end
  opts.on("-j", "--plistSettingsPath PATH", "path to settings plist") do |path|
    options["plistSettingsPath"] = (Pathname.new path).realpath().to_s
  end
  opts.on("-d", "--hardwareID ID", "hardware id of device you run on") do |v|
    options["hardwareID"] = v
  end
  opts.on("-i", "--implementation IMPL", "Device tests implementation (iPhone|iPad)") do |impl|
    options["implementation"] = impl
  end

  
  opts.separator "######################################################################"
  
  opts.on("-b", "--simdevice DEVICE", "Run on given simulated device           Defaults to \"iPhone Retina (4-inch)\"") do |v|
    options["simdevice"] = v
  end
    opts.on("-z", "--simversion VERSION", "Run on given simulated iOS version     Defaults to \"iOS 7.0\"") do |v|
    options["simversion"] = v
  end
  opts.on("-l", "--simlanguage LANGUAGE", "Run on given simulated iOS language     Defaults to \"en\"") do |v|
    options["simlanguage"] = v
  end
  
  opts.separator "######################################################################"
  
  opts.on("-f", "--skip-build", "Just automate; assume already built") do |v|
    options["skipBuild"] = TRUE
  end
  opts.on("-e", "--skip-set-sim", "Assume that simulator has already been chosen and properly reset") do |v|
    options["skipSetSim"] = TRUE
  end
  opts.on("-k", "--skip-kill-after", "Do not kill the simulator after the run") do |v|
    options["skipKillAfter"] = TRUE
  end
  
  opts.separator "######################################################################"
  
  opts.on("-c", "--coverage", "Generate coverage files") do |v|
    options["coverage"] = TRUE
  end
  opts.on("-r", "--report", "Generate Xunit reports in buildArtifacts/UIAutomationReport folder") do |v|
    options["report"] = TRUE
  end
  opts.on("-v", "--verbose", "Show verbose output") do |v|
    options["verbose"] = TRUE
  end
  opts.on("-m", "--timeout TIMEOUT", "startup timeout") do |v|
    options["timeout"] = v
  end
  opts.on("-w", "--random-seed SEED", "Randomize test order based on given integer seed") do |v|
    options["randomSeed"] = v
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

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
