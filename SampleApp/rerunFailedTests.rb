require 'bundler/setup'
require 'illuminator'
require 'pathname'

# TODO: helpful message if file isn't supplied.
# ARGV[0] should be a path ending in IlluminatorRerunFailedTestsSettings.json

override_options = lambda {|opts| opts}

success = Illuminator::rerun(ARGV[0], override_options)

exit 1 unless success
