require 'rubygems'
require 'colorize'

require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

class XcodeBuilder
  attr_accessor :configuration
  attr_accessor :sdk
  attr_accessor :arch
  attr_accessor :scheme
  attr_accessor :workspace
  attr_accessor :destination
  attr_accessor :xcconfig
  attr_accessor :doClean
  attr_accessor :doTest
  attr_accessor :doBuild
  attr_accessor :doArchive

  attr_reader :exitCode

  def initialize
    @parameters = Hash.new
    @environmentVars = Hash.new
    @workspace = nil
    @doClean = FALSE
    @doTest = FALSE
    @doBuild = TRUE
    @doArchive = FALSE
    @exitCode = nil
  end

  def addParameter(parameterName = '',parameterValue = '')
    @parameters[parameterName] = parameterValue
  end

  def addEnvironmentVariable(parameterName = '',parameterValue = '')
    @environmentVars[parameterName] = parameterValue
  end

  def _assembleConfig
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


  def _buildCommand
    usePipefail = false  # debug option
    self._assembleConfig

    parameters = ''
    environmentVars = ''
    tasks = ''

    @parameters.each      { |name, value| parameters << " -#{name} #{value}" }
    @environmentVars.each { |name, value| environmentVars << " #{name}=#{value}" }

    tasks << ' clean'    if @doClean
    tasks << ' build'    if @doBuild
    tasks << ' archive'  if @doArchive
    tasks << ' test'     if @doTest

    command = ''
    command << 'set -o pipefail && ' if usePipefail
    command << 'xcodebuild'
    command << parameters << environmentVars << tasks
    command << " | tee '#{self.logfilePath}' | xcpretty -c -r junit"
    command << ' && exit ${PIPESTATUS[0]}' unless usePipefail

    puts 'created command:'
    puts command.green
    command
  end


  def logfilePath
    logFile = File.join(BuildArtifacts.instance.console, 'xcodebuild.log')
  end


  def _executeBuildCommand command
    process = IO.popen(command) do |io|
      io.each {|line| puts line}
      io.close
    end

    ec = $?
    @exitCode = ec.exitstatus
    return @exitCode == 0
  end


  def build
    command = self._buildCommand

    # switch to a directory (if desired) and build
    directory = Dir.pwd
    Dir.chdir(@workspace) unless @workspace.nil?
    retval = self._executeBuildCommand command
    Dir.chdir(directory) unless @workspace.nil?

    retval
  end

end
