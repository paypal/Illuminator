
class InstrumentsListener

  def receive (message)
    puts message.fullLine
    puts "  date:    #{message.date}"
    puts "  time:    #{message.time}"
    puts "  tz:      #{message.tz}"
    puts "  status:  #{message.status}"
    puts "  message: #{message.message}"
    puts "  --- If you're seeing this, InstrumentsListener.receive was not overridden"
    puts
  end

  def onAutomationFinished(failed)
    puts " ==="
    puts " === If you're seeing this, InstrumentsListener.onAutomationFinshed was not overridden"
    puts " ==="
    puts
  end

end
