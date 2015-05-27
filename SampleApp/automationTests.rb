require 'bundler/setup'
require 'illuminator'
require 'pathname'

options = {}
parser_factory = Illuminator::ParserFactory.new

parser_factory.prepare({"b" => 'iPhone 5'}, # the default sim device is iPhone 5
                      {},                  # no extra parse flags are being defined
                      {})                  # no argument processing overrides are being provided
parser = parser_factory.build_parser(options, 'APDasdq#xtoni#rvmw#bzl#Bfek#')

option_struct = parser.parse ARGV

# hard code the project-specific information we have
option_struct.xcode.project_dir = File.expand_path(File.dirname(__FILE__)) # Xcode project file is in this directory
option_struct.xcode.app_name = 'AutomatorSampleApp'
option_struct.xcode.workspace = 'AutomatorSampleApp.xcworkspace'
option_struct.xcode.scheme = 'AutomatorSampleApp'
option_struct.javascript.implementation = 'iPhone'
option_struct.javascript.test_path = Illuminator::HostUtils.realpath('SampleTests/tests/AllTests.js') # must be full path

success = Illuminator::run_with_options option_struct
exit 1 unless success
