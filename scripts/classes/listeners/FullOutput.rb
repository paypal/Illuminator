
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

class FullOutput < InstrumentsListener

  def reset
  end

  def receive (message)
    puts message.fullLine
  end

  def onAutomationFinished
  end

end
