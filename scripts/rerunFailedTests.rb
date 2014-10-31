require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/BuildArtifacts.rb')

workspace = Dir.pwd

puts ARGV.to_s

# TODO: helpful message if file isn't supplied

# load config from supplied path
savedConfig = JSON.parse( IO.read(ARGV[0]) )

# write custom config if needed -- THIS IS NAIVE so watch out
unless savedConfig["customConfig"].nil?
  f = File.open(BuildArtifacts.instance.illuminatorCustomConfigFile, 'w')
  f << JSON.pretty_generate(savedConfig["customConfig"])
  f.close
  savedConfig["options"]["customJSConfigPath"] = BuildArtifacts.instance.illuminatorCustomConfigFile
end

success = IlluminatorFramework.runWithOptions savedConfig["options"], workspace
exit 1 unless success
