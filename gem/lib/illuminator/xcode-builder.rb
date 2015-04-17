require 'colorize'

require_relative './build-artifacts'
require_relative './host-utils'

module Illuminator
  class XcodeBuilder
    attr_accessor :project
    attr_accessor :configuration
    attr_accessor :sdk
    attr_accessor :arch
    attr_accessor :scheme
    attr_accessor :projectDir
    attr_accessor :workspace
    attr_accessor :destination
    attr_accessor :xcconfig
    attr_accessor :doClean
    attr_accessor :doTest
    attr_accessor :doBuild
    attr_accessor :doArchive

    attr_reader :exitCode

    def initialize
      @parameters      = Hash.new
      @environmentVars = Hash.new
      @projectDir      = nil
      @doClean         = FALSE
      @doTest          = FALSE
      @doBuild         = TRUE
      @doArchive       = FALSE
      @exitCode        = nil
    end

    def setBuildArtifactsRoot rootDir
      BuildArtifacts.instance.setRoot(rootDir)
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
        'project'       => @project,
        'configuration' => @configuration,
        'sdk'           => @sdk,
        'arch'          => @arch,
        'scheme'        => @scheme,
        'destination'   => @destination,
        'workspace'     => @workspace,
        'xcconfig'      => @xcconfig,
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
      command << " | tee '#{self.logfilePath}'"
      unless Illuminator::HostUtils.which("xcpretty").nil?  # use xcpretty if available
        command << " | xcpretty -c -r junit -o #{BuildArtifacts.instance.xcprettyReportFile}"
      end
      command << ' && exit ${PIPESTATUS[0]}' unless usePipefail

      command
    end


    def logfilePath
      logFile = File.join(BuildArtifacts.instance.console, 'xcodebuild.log')
    end


    def _executeBuildCommand command
      puts command.green
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
      retval = nil
      begin
        Dir.chdir(@projectDir) unless @projectDir.nil?
        retval = self._executeBuildCommand command
      ensure
        Dir.chdir(directory) unless @projectDir.nil?
      end

      retval
    end

  end
end
