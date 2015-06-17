
require_relative 'instruments-listener'

module StopDetectorEventSink

  # fatal means that restarting instruments won't fix it
  def stop_detector_triggered(fatal, message)
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# StopDetector monitors the logs for things that indicate that instruments should be stopped (user errors)
#  - a message that automation has stopped
#  - a message that the user needs to enter credentials
#  - etc
class StopDetector < InstrumentsListener

  attr_accessor :event_sink

  def trigger(fatal, message)
    # assume developer has set event_sink already
    @event_sink.stop_detector_triggered(fatal, message)
  end

  def receive message
    # error cases that indicate successful stop but involve errors that won't be fixed by a restart

    # like if instruments says it stopped
    trigger(false, message.message) if :stopped == message.status

    # or if instruments prompts for username/password
    p1 = "instruments: Instruments wants permission to analyze other processes."
    p2 = "Please enter an administrator username and password to allow this."

    p = /#{p1} #{p2}/
    if p =~ message.full_line
      trigger(true, "Instruments needs permission to analyze other processes.  Please run instruments manually to permit this.")
    end

  end

  def on_automation_finished
  end

end
