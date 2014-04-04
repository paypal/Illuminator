require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/ParameterStorage.rb')


plistPath = './buildArtifacts/buildParameters.plist'

ARGV.each do|parameter|
  argName, *rest = parameter.split('=' , 2)
  argValue = rest[0]
  if argName == '--help'
    puts 'Parameter storage script'
    puts '####################################################################################################'
    puts 'Used primarily for xcode to write down some parameters to js and plist files for uiautomation and coverage to work'
    puts "Will store any given parameter with any given value to #{plistPath}"
    puts '####################################################################################################'
    puts 'Usage'
    puts '####################################################################################################'
    puts "ruby #{File.expand_path(File.dirname(__FILE__))}/parameterStorage.rb  parameter=value"
    exit(1)
  end
end


Dir.chdir(File.dirname(__FILE__) + "/../")
storage = PLISTStorage.new
storage.clearAtPath(plistPath)
ARGV.each do|parameter|
  argName, *rest = parameter.split('=' , 2)
  argValue = rest[0]
  storage.addParameterToStorage(argName, argValue)
end
storage.saveToPath(plistPath)