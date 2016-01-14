require 'bundler/setup'
require 'illuminator'

# Change directory to sample app and use that for the project dir
Dir.chdir File.expand_path(File.dirname(__FILE__))

all_test_path = 'SampleTests/tests/AllTests.js'
all_test_path = Illuminator::HostUtils.realpath(all_test_path)

# Hard-coded options

options = Illuminator::Options.new
options.build_artifacts_dir = File.join(Dir.pwd, "buildArtifacts")
options.xcode.app_name = 'AutomatorSampleApp'
options.xcode.scheme = 'AutomatorSampleApp'
options.xcode.workspace = 'AutomatorSampleApp.xcworkspace'
options.xcode.xcconfig = nil
options.xcode.project_dir = Dir.pwd


options.illuminator.entry_point = 'runTestsByTag'
options.illuminator.test.tags.any = ['smoke']
options.illuminator.clean.xcode = true
options.illuminator.clean.artifacts = true
options.illuminator.clean.no_delay = true
options.illuminator.task.build = true
options.illuminator.task.automate = true
options.illuminator.task.set_sim = true
options.simulator.device = 'iPhone 6'
options.simulator.language = 'en'
options.simulator.kill_after = true

options.instruments.do_verbose = false
options.instruments.timeout = 30

options.javascript.test_path = all_test_path
options.javascript.implementation = 'iPhone'

if Illuminator::XcodeUtils.instance.is_xcode_major_version 5
  options.simulator.device = 'iPhone Retina (4-inch)'
end

options.simulator.version = '9.1'
success8 = Illuminator::run_with_options options

# options.illuminator.clean.xcode = false
# options.illuminator.clean.artifacts = false
# options.illuminator.task.build = false
# options.simulator.version = '8.1'
# success7 = Illuminator::run_with_options options

exit 1 unless success8 # and success7
