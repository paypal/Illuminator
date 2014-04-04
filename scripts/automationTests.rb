require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationConfig.rb')

workspace = Dir.pwd

# This must be
Dir.chdir(File.dirname(__FILE__) + "/../")


####################################################################################################
# Argument catcher
####################################################################################################

defaultXcode = '/Applications/Xcode.app'
testToRun = nil
report = FALSE
tagsAny = ''
tagsAll = ''
tagsNone = ''
stage = 'stage2mb024'
device = 'iPhone'
randomSeed = nil
doBuild = TRUE
pretty = FALSE
doSetSimulator = TRUE
simDevice = 'iPhone Retina (4-inch)'
simVersion = 'iOS 7.0'
simLanguage = 'en'
doKillAfter = TRUE
doCoverage = FALSE
timeout = 30
hardwareID = nil



ARGV.each do|parameter|
  argName, *rest = parameter.split('=' , 2)
  argValue = rest[0]
  if argName == '--xcode'
    defaultXcode = argValue
  elsif argName == '--test'
    testToRun = argValue
  elsif argName == '--tags-any'
    tagsAny = argValue
  elsif argName == '--tags-all'
    tagsAll = argValue
  elsif argName == '--tags-none'
    tagsNone = argValue
  elsif argName == '--device'
    device = argValue
  elsif argName == '--stage'
    stage = argValue
  elsif argName == '--simdevice'
    simDevice = argValue
  elsif argName == '--simversion'
    simVersion = argValue
  elsif argName == '--simlanguage'
    simLanguage = argValue
  elsif argName == '--report'
    report = TRUE
  elsif argName == '--random-seed'
    randomSeed = argValue
  elsif argName == '--skip-build'
    doBuild = FALSE
  elsif argName == '--skip-set-sim'
    doSetSimulator = FALSE
  elsif argName == '--pretty'
    pretty = TRUE
  elsif argName == '--skip-kill-after'
    doKillAfter = FALSE
  elsif argName == '--coverage'
    doCoverage = TRUE
  elsif argName == '--timeout'
    timeout = argValue
  elsif argName == '--hardwareID'
    hardwareID = argValue
  elsif argName == '--help'
    puts 'Runs UIAutomation tests on iPhone target'
    puts '####################################################################################################'
    puts '== Usage'
    puts '####################################################################################################'
    puts 'ruby scripts/buildMachine/automationTests.rb  Runs all unit tests in tests folder'
    puts '--help             Shows this message'
    puts '--xcode            Sets path to default Xcode instalation               Defaults to /Applications/Xcode.app'
    puts '--report           Generate Xunit reports in UIAutomationReport folder'
    puts '--tags-any         Run tests with any of the given tags                 example --tags-any=smoke,cash'
    puts '--tags-all         Run tests with all of the given tags                 example --tags-all=fake'
    puts '--tags-none        Run tests with none of the given tags                example --tags-none=JP'
    puts '--device           Run specific tests on given device scheme            Defaults to iPhone'
    puts '--stage            Run tests on given stage                             Defaults to stage2mb024'
    puts '--random-seed      Randomize test order based on given integer seed     example --random-seed=3'
    puts '--simdevice        Run on given simulated device                        Defaults to "iPhone Retina (4-inch)"'
    puts '--simversion       Run on given simulated iOS version                   Defaults to "iOS 7.0"'
    puts '--simlanguage      Run on given simulated iOS language                  Defaults to "en"'
    puts '--skip-build       Just automate; assume already built'
    puts '--skip-set-sim     Assume that simulator has already been chosen and properly reset'
    puts '--skip-kill-after  Do not kill the simulator after the run'
    puts '--coverage         Generate coverage files'
    puts '--timeout          startup timeout'
    puts '--pretty           nice and pretty output'
    puts '--hardwareID       if you want to run on device'
    exit(1)
  end
end

####################################################################################################
# Storing parameters
####################################################################################################

tagsAny_arr = Array.new(0)
tagsAny_arr = tagsAny.split(',') unless tagsAny.empty?

tagsAll_arr = Array.new(0)
tagsAll_arr = tagsAll.split(',') unless tagsAll.empty?

tagsNone_arr = Array.new(0)
tagsNone_arr = tagsNone.split(',') unless tagsNone.empty?

plistConfig = AutomationConfig.new(device, stage, simVersion, tagsAny_arr, tagsAll_arr, tagsNone_arr, randomSeed, hardwareID)



####################################################################################################
# Script action
####################################################################################################

runner = AutomationRunner.new(defaultXcode, device, doBuild, doCoverage, doSetSimulator, simDevice, simVersion, simLanguage, timeout, hardwareID, workspace)
plistConfig.save() # must save AFTER automationRunner initializes
runner.runAllTests(report, doKillAfter, pretty, hardwareID)
