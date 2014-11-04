require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/AutomationArgumentParserFactory.rb')

workspace = Dir.pwd

options = {}
parserFactory = AutomationParserFactory.new()
parserFactory.prepare()
parser = parserFactory.buildParser(options, 'xpatonsjdiq#bzl#fek#crvmw')

parser.parse! ARGV

success = IlluminatorFramework.runWithOptions options, workspace
exit 1 unless success
