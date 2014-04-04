require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/ParameterStorage.rb')

ARGV.each do|parameter|
  argName, *rest = parameter.split('=' , 2)
  argValue = rest[0]
  if argName == '--help'
    puts 'Parameter storage script'
    puts '####################################################################################################'
    puts 'Used primarily for xcode to write down some parameters to js and plist files for uiautomation and coverage to work'
    puts 'Will store any given parameter with any given value to buildParameters.plist and UIAutomation/environment.js files'
    puts 'Would be cool to parametrize locations and formats'
    puts '####################################################################################################'
    puts 'Usage'
    puts '####################################################################################################'
    puts 'ruby scripts/buildMachine/parameterStorage.rb  parameter=value'
    exit(1)
  end
end


Dir.chdir(File.dirname(__FILE__) + "/../../")
jsPath = 'UIAutomation/environment.js'
plistPath = 'buildParameters.plist'
storage = PLISTStorage.new
jsStorage = JSStorage.new
storage.clearAtPath(plistPath)
jsStorage.clearAtPath(jsPath)
ARGV.each do|parameter|
  argName, *rest = parameter.split('=' , 2)
  argValue = rest[0]
  storage.addParameterToStorage(argName, argValue)
  jsStorage.addParameterToStorage(argName, argValue)
end
storage.saveToPath(plistPath)
jsStorage.saveToPath(jsPath)