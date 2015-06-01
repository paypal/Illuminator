
require 'logger'
require_relative '../build-artifacts'
require_relative './instruments-listener'

class ConsoleLogger < InstrumentsListener

  def initialize
    @run_number = 0
    @logger = nil
  end

  def prepare_logger
    return unless @logger.nil?
    @run_number += 1
    filename = File.join(Illuminator::BuildArtifacts.instance.console, "instruments#{@run_number.to_s.rjust(3, "0")}.log")
    FileUtils.rmtree filename
    @logger = Logger.new(filename)
  end

  def receive (message)
    prepare_logger
    @logger << message.full_line
    @logger << "\n"
  end

  def on_automation_finished
    @logger.close unless @logger.nil?
    @logger = nil
  end

end
