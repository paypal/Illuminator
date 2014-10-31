require 'pathname'
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/IlluminatorFramework.rb')
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
options['simDevice'] = 'iPhone Retina (4-inch)'
options['simLanguage'] = 'en'
options['tagsAny'] = 'smoke'
options['testPath'] = allTestPath
options['timeout'] = 30
options['verbose'] = FALSE
options['report'] = TRUE
options['skipBuild'] = FALSE

success = IlluminatorFramework.runWithOptions options, workspace
exit 1 unless success
