
require_relative './instruments-listener'

class FullOutput < InstrumentsListener

  def receive (message)
    puts message.fullLine
  end

  def onAutomationFinished
  end

end
