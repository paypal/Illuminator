require 'bundler/setup'
require 'illuminator'
require 'pathname'

workspace = Dir.pwd

# TODO: helpful message if file isn't supplied

overrideOptions = lambda {|opts| opts}

success = Illuminator::.reRun(ARGV[0], workspace, overrideOptions)

exit 1 unless success
