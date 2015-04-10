require 'bundler/setup'
require 'illuminator'
require 'pathname'

# TODO: helpful message if file isn't supplied.
# ARGV[0] should be a path ending in IlluminatorRerunFailedTestsSettings.json

overrideOptions = lambda {|opts| opts}

success = Illuminator::reRun(ARGV[0], overrideOptions)

exit 1 unless success
