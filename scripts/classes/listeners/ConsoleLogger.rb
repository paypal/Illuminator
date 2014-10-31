
require File.join(File.expand_path(File.dirname(__FILE__)), '../BuildArtifacts.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

class ConsoleLogger < InstrumentsListener

  def initialize
    @lines = Array.new
  end

  def receive (message)
    @lines << message.fullLine
  end

  def onAutomationFinished
    f = File.open(File.join(BuildArtifacts.instance.console, 'instruments.log'), 'w')
    f.write(@lines.join("\n"))
    f.close
  end

end
