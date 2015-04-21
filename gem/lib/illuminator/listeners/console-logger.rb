
require 'logger'
require_relative '../build-artifacts'
require_relative './instruments-listener'

class ConsoleLogger < InstrumentsListener

  def initialize
    @runNumber = 0
    @logger = nil
  end

  def prepareLogger
    return unless @logger.nil?
    @runNumber += 1
    filename = File.join(Illuminator::BuildArtifacts.instance.console, "instruments#{@runNumber.to_s.rjust(3, "0")}.log")
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
