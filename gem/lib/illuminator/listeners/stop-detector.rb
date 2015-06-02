
require_relative 'instruments-listener'

module StopDetectorEventSink

  def stop_detector_triggered
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# StopDetector monitors the logs for things that indicate that instruments should be stopped (user errors)
#  - a message that automation has stopped
#  - a message that the user needs to enter credentials
#  - etc
class StopDetector < InstrumentsListener

  attr_accessor :event_sink

  def trigger
    # assume developer has set event_sink already
    @event_sink.stop_detector_triggered
  end

  def receive message
    # error cases that indicate successful stop but involve errors that won't be fixed by a restart
    trigger if :stopped == message.status
  end

  def on_automation_finished
  end

end
