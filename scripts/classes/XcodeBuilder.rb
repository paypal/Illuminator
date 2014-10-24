require 'rubygems'
require 'colorize'

require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

class XcodeBuilder
  attr_accessor :configuration
  attr_accessor :sdk
  attr_accessor :arch
  attr_accessor :scheme
  attr_accessor :destination
  attr_accessor :xcconfig
  attr_accessor :doClean
  attr_accessor :doTest
  attr_accessor :doBuild
  attr_accessor :doArchive


  def initialize
    @parameters = Hash.new
    @environmentVars = Hash.new
    @doClean = FALSE
    @doTest = FALSE
    @doBuild = TRUE
    @doArchive = FALSE
  end

  def addParameter(parameterName = '',parameterValue = '')
    @parameters[parameterName] = parameterValue
  end

  def addEnvironmentVariable(parameterName = '',parameterValue = '')
    @environmentVars[parameterName] = parameterValue
  end

  def assembleConfig
    # put standard parameters into parameters
    keyDefs = {
      'configuration' => @configuration,
      'sdk' => @sdk,
      'arch' => @arch,
      'scheme' => @scheme,
      'destination' => @destination,
      'xcconfig' => @xcconfig,
    }

    keyDefs.each do |key, value|
        self.addParameter(key, value) unless value.nil?
    end
  end


  def buildCommand
    self.assembleConfig

    parameters = ''
    environmentVars = ''
    tasks = ''

    @parameters.each      { |name, value| parameters << " -#{name} #{value}" }
    @environmentVars.each { |name, value| environmentVars << " #{name}=#{value}" }

    tasks << ' clean'    if @doClean
    tasks << ' build'    if @doBuild
    tasks << ' archive'  if @doArchive
    tasks << ' test'     if @doTest

    command = 'set -o pipefail && xcodebuild'
    command << parameters << environmentVars << tasks
    command << " | tee '#{self.logfilePath}' | xcpretty -c -r junit"
    puts 'created command:'
    puts command.green
    command
  end


  def logfilePath
    logFile = File.join(BuildArtifacts.instance.console, 'xcodebuild.log')
  end


  def run
    command = self.buildCommand

    process = IO.popen(command) do |io|
      io.each {|line| puts line}
      io.close
      exitCode = $?.to_i
      unless exitCode == 0
        puts "xcodebuild exit code is #{exitCode}".red
        unless exitCode == 256  # xcode returns this, no documentation as to why
          puts 'Build failed, check logs for results'.red
          exit $?.to_i
        end
      end
    end
  end

end
