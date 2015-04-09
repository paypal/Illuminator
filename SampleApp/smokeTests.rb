require 'bundler/setup'
require 'illuminator'

# Change directory to sample app and use that for the workspace
Dir.chdir File.expand_path(File.dirname(__FILE__))
workspace = Dir.pwd

allTestPath = 'SampleTests/tests/AllTests.js'
allTestPath = Illuminator::HostUtils.realpath(allTestPath)

# Hard-coded options

options = Illuminator::Options.new
options.xcode.appName = 'AutomatorSampleApp'
options.xcode.scheme = 'AutomatorSampleApp'
options.xcode.workspaceFile = 'AutomatorSampleApp.xcworkspace'

options.illuminator.entryPoint = 'runTestsByTag'
options.illuminator.test.tags.any = ['smoke']
options.illuminator.clean.xcode = true
options.illuminator.clean.artifacts = true
options.illuminator.clean.noDelay = true
options.illuminator.task.build = true
options.illuminator.task.automate = true
options.illuminator.task.setSim = true
options.simulator.device = 'iPhone 5'
options.simulator.language = 'en'
options.simulator.killAfter = true

options.instruments.doVerbose = false
options.instruments.timeout = 30

options.javascript.testPath = allTestPath
options.javascript.implementation = 'iPhone'

if Illuminator::XcodeUtils.instance.isXcodeMajorVersion 5
  options.simulator.device = 'iPhone Retina (4-inch)'
end

options.simulator.version = '8.1'
success8 = Illuminator::runWithOptions options, workspace

options.illuminator.clean.xcode = false
options.illuminator.clean.artifacts = false
options.illuminator.task.build = false
options.simulator.version = '7.1'
success7 = Illuminator::runWithOptions options, workspace

exit 1 unless success7 and success8
