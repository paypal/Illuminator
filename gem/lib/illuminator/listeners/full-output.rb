
require_relative './instruments-listener'

class FullOutput < InstrumentsListener

  def receive (message)
    puts message.full_line
  end

  def on_automation_finished
  end

end
