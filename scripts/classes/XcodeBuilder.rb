require 'rubygems'
require 'colorize'

require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

class XcodeBuilder

  def initialize
    @parameters = Hash.new
    @environmentVariables = Hash.new
    @shouldClean = FALSE
    @shouldTest = FALSE
    @shouldBuild = TRUE
    @shouldArchive = FALSE
  end

  def addParameter(parameterName = '',parameterValue = '')
    @parameters[parameterName] = parameterValue
  end

  def addEnvironmentVariable(parameterName = '',parameterValue = '')
    @environmentVariables[parameterName] = parameterValue
  end

  def skipBuild
    @shouldBuild = FALSE
  end

  def clean
    @shouldClean = TRUE
  end

  def archive
    @shouldArchive = TRUE
  end

  def test
    @shouldTest = TRUE
  end


  def buildCommand
    command = 'set -o pipefail && xcodebuild'
    parameters = ''
    environmentVariables = ''

    @parameters.each do |name, value|
      parameters << " -#{name} #{value}"
    end

    @environmentVariables.each do |name, value|
      parameters << " #{name}=#{value}"
    end

    command << parameters << environmentVariables

    if @shouldClean
      command << ' clean'
    end

    if @shouldBuild
      command << ' build'
    end

    if @shouldArchive
      command << ' archive'
    end

    if @shouldTest
      command << ' test'
    end

    logPath = BuildArtifacts.instance.console
    command << " | tee '#{logPath}/xcodebuild.log' | xcpretty -c"

    # reporting
    command << ' -r junit'

    puts 'created command:'
    puts command.green
    command

  end

  def run
    command = self.buildCommand
    output = ""

    process = IO.popen(command) do |io|
      while line = io.gets
        line.chomp!
        puts line
        output = output + line
      end
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

  def killSim
    killCommand = "killall 'iPhone Simulator'"
    IO.popen killCommand do |io|
      io.each {||}
    end
  end
end
