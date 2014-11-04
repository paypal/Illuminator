require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/IlluminatorFramework.rb')

workspace = Dir.pwd

# TODO: helpful message if file isn't supplied

overrideOptions = {}
overrideCustomOptions = {}

success = IlluminatorFramework.reRun(ARGV[0], workspace, overrideOptions, overrideCustomOptions)

exit 1 unless success
