require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/IlluminatorArgumentParsing.rb')

workspace = Dir.pwd

options = {}
parserFactory = IlluminatorParserFactory.new()
parserFactory.prepare()
parser = parserFactory.buildParser(options, 'xpatonsjdiq#bzl#fek#crvmw')

optionStruct = parser.parse! ARGV

success = IlluminatorFramework.runWithOptions optionStruct, workspace
exit 1 unless success
