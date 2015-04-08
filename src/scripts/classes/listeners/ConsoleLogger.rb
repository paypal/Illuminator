
require 'logger'
require File.join(File.expand_path(File.dirname(__FILE__)), '../BuildArtifacts.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

class ConsoleLogger < InstrumentsListener

  def initialize
    @runNumber = 0
    @logger = nil
  end

  def prepareLogger
    return unless @logger.nil?
    @runNumber += 1
    filename = File.join(BuildArtifacts.instance.console, "instruments#{@runNumber.to_s.rjust(3, "0")}.log")
    FileUtils.rmtree filename
    @logger = Logger.new(filename)
  end

  def receive (message)
    self.prepareLogger
    @logger << message.fullLine
    @logger << "\n"
  end

  def onAutomationFinished
    @logger.close unless @logger.nil?
    @logger = nil
  end

end
