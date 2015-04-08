
require_relative 'instruments-listener'

module StopDetectorEventSink

  def stopDetectorTriggered
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# StopDetector monitors the logs for things that indicate that instruments should be stopped (user errors)
#  - the saltinel for the intended test list
#  - a javascript error
#  - etc
class StopDetector < InstrumentsListener

  attr_accessor :eventSink

  def trigger
    # assume developer has set eventSink already
    @eventSink.stopDetectorTriggered
  end

  def receive message
    # error cases that indicate successful stop but involve errors that won't be fixed by a restart
    self.trigger if :stopped == message.status
  end

  def onAutomationFinished
  end

end
