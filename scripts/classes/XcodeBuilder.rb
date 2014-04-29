require 'rubygems'
require 'colorize'

class XcodeBuilder

  def initialize
    @parameters = Hash.new
    @environmentVariables = Hash.new
    @shouldClean = FALSE
    @shouldTest = FALSE
    @shouldReport = FALSE
  end

  def addParameter(parameterName = '',parameterValue = '')
    @parameters[parameterName] = parameterValue
  end

  def addEnvironmentVariable(parameterName = '',parameterValue = '')
    @environmentVariables[parameterName] = parameterValue
  end

  def clean
    @shouldClean = TRUE
  end

  def test
    @shouldTest = TRUE
  end

  def report
    @shouldReport = TRUE
  end


  def buildCommand
    command = 'xcodebuild'
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

    command << ' build'

    if @shouldTest
      command << ' test'
    end
    
    command << " | tee '#{File.dirname(__FILE__)}/../../buildArtifacts/xcodebuild.log' | xcpretty -c"
  
    if @shouldTest
      command << ' -r junit'
    end
    
    puts 'created command:'
    puts command.green
    return command

  end
  
  def run
    command = self.buildCommand
    output = ""
    IO.popen(command).each do |line|
      puts line
      output = output + line
    end
    return output
  end

  def killSim
    killCommand = "killall 'iPhone Simulator'"
    IO.popen killCommand do |io|
      io.each {||}
    end
  end
end