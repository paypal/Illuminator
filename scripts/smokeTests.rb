require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/XcodeUtils.rb')

Dir.chdir 'SampleApp/AutomatorSampleApp'
workspace = Dir.pwd

#ruby ../../scripts/automationTests.rb -s AutomatorSampleApp -t smoke -p ../../SampleApp/SampleTests/tests/AllTests.js
allTestPath = '../../SampleApp/SampleTests/tests/AllTests.js'
allTestPath = (Pathname.new (allTestPath)).realpath.to_s

####################################################################################################
# Storing custom parameters
####################################################################################################

options = {}

options['entryPoint'] = 'runTestsByTag'
options['implementation'] = 'iPhone'
options['appName'] = 'AutomatorSampleApp'
options['scheme'] = 'AutomatorSampleApp'
options['simVersion'] = '7.1'
options["simDevice"] = 'iPhone 5'
options['simLanguage'] = 'en'
options['tagsAny'] = 'smoke'
options['testPath'] = allTestPath
options['timeout'] = 30
options['verbose'] = FALSE
options['report'] = TRUE
options['skipBuild'] = FALSE

if XcodeUtils.instance.isXcodeMajorVersion 5
  options['simDevice'] = 'iPhone Retina (4-inch)'
end

success = IlluminatorFramework.runWithOptions options, workspace
exit 1 unless success
