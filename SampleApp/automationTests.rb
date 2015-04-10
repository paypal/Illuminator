require 'bundler/setup'
require 'illuminator'
require 'pathname'

options = {}
parserFactory = Illuminator::ParserFactory.new

parserFactory.prepare({"b" => 'iPhone 5'}, # the default sim devie is iPhone 5
                      {},                  # no extra parse flags are being defined
                      {})                  # no argument processing overrides are being provided
parser = parserFactory.buildParser(options, 'APDasdq#xtoni#rvmw#bzl#Bfek#')

optionStruct = parser.parse ARGV

# hard code the project-specific information we have
optionStruct.xcode.projectDir = File.expand_path(File.dirname(__FILE__)) # Xcode project file is in this directory
optionStruct.xcode.appName = 'AutomatorSampleApp'
optionStruct.xcode.workspace = 'AutomatorSampleApp.xcworkspace'
optionStruct.xcode.scheme = 'AutomatorSampleApp'
optionStruct.javascript.implementation = 'iPhone'
optionStruct.javascript.testPath = Illuminator::HostUtils.realpath('SampleTests/tests/AllTests.js') # must be full path

success = Illuminator::runWithOptions optionStruct
exit 1 unless success
