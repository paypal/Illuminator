#!/usr/bin/env ruby
require 'bundler/setup'
require 'illuminator'
require 'pathname'

options = {}
parser_factory = Illuminator::ParserFactory.new

parser_factory.prepare({},  # no defaults are being set
                       {},  # no extra parse flags are being defined
                       {})  # no argument processing overrides are being provided

# Each command line option has a single-character code, so we lay out the order of the options (# for separator) here
#parser = parser_factory.build_parser(options, 'APDasdq#xtoni#rvmw#bzl#Bfek#')
parser = parser_factory.build_parser(options, 'AyfEBxrc#aDPWqs#dbzlek#vmp#xtoniw#')

# read the options into an Illuminator::Options structure
option_struct = parser.parse ARGV

# use the defined options
success = Illuminator::run_with_options option_struct
exit 1 unless success
