require 'bundler/setup'
require 'illuminator'
require 'pathname'

options = {}
parserFactory = Illuminator::ParserFactory.new

parserFactory.prepare({"b" => 'iPhone 5'}, # the default sim devie is iPhone 5
                      {},                  # no extra parse flags are being defined
                      {})                  # no argument processing overrides are being provided
parser = parserFactory.buildParser(options, 'asdq#xtoni#rvmw#bzl#Bfek#')

optionStruct = parser.parse ARGV

# hard code the project-specific information we have
optionStruct.xcode.appName = 'AutomatorSampleApp'
optionStruct.xcode.workspaceFile = 'AutomatorSampleApp.xcworkspace'
optionStruct.xcode.scheme = 'AutomatorSampleApp'
optionStruct.javascript.implementation = 'iPhone'
optionStruct.javascript.testPath = Illuminator::HostUtils.realpath('../SampleTests/tests/AllTests.js') # must be full path

workspace = Dir.pwd


success = Illuminator::runWithOptions optionStruct, workspace
exit 1 unless success
