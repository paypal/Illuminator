
require_relative './saltinel-listener'

module StartDetectorEventSink

  def start_detector_triggered
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# StartDetector monitors the logs for things that indicate a successful startup of instruments
#  - the saltinel for the intended test list
#  - a javascript error
#  - etc
class StartDetector < SaltinelListener

  attr_accessor :event_sink

  def on_init
    @already_started = false
  end

  def trigger
    # assume developer has set event_sink already
    @event_sink.start_detector_triggered unless @already_started
    @already_started = true
  end

  def receive message
    super # run the SaltinelListener processor

    # error cases that indicate successful start but involve errors that won't be fixed by a restart
    self.trigger if :error == message.status and /Script threw an uncaught JavaScript error:/ =~ message.message

    # Instruments usage error generally means we can't recover... unless it's a device booting issue
    if /^Instruments Usage Error :/ =~ message.full_line
      unless /^Instruments Usage Error : Timed out waiting for device to boot:/ =~ message.full_line
        self.trigger
      end
    end
  end

  def on_saltinel inner_message
    self.trigger if /Saved intended test list to/ =~ inner_message
    self.trigger if /Successful launch/ =~ inner_message
  end

  def on_automation_finished
  end

end
