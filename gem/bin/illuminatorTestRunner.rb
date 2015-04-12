#!/usr/bin/env ruby
require 'bundler/setup'
require 'illuminator'
require 'pathname'

options = {}
parserFactory = Illuminator::ParserFactory.new

parserFactory.prepare({},  # no defaults are being set
                      {},  # no extra parse flags are being defined
                      {})  # no argument processing overrides are being provided

# Each command line option has a single-character code, so we lay out the order of the options (# for separator) here
#parser = parserFactory.buildParser(options, 'APDasdq#xtoni#rvmw#bzl#Bfek#')
parser = parserFactory.buildParser(options, 'AyfEBxrc#aDPWqs#dbzlek#vmp#xtoniw#')

# read the options into an Illuminator::Options structure
optionStruct = parser.parse ARGV

# use the defined options
success = Illuminator::runWithOptions optionStruct
exit 1 unless success
