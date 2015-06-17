
module TraceErrorDetectorEventSink

  # fatal means that restarting instruments won't fix it
  def trace_error_detector_triggered(fatal, message)
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# TraceErrorDetector monitors the logs for things that indicate a transient failure to start instruments
#  - "unable to install app"
#  - etc
class TraceErrorDetector < InstrumentsListener

  attr_accessor :event_sink

  def trigger(fatal, message)
    @event_sink.trace_error_detector_triggered(fatal, message)
  end

  def receive message
    itr = "Instruments Trace Error : Target failed to run:"
    if message.full_line =~ /#{itr} Unable to install app with path:/
      trigger(false, "Failed to install app because #{message.full_line.split(': ')[-1]}")
    elsif message.full_line =~ /#{itr} The operation couldn’t be completed./
      trigger(false, "An operation couldn't be completed because #{message.full_line.split(': ')[-1]}")
    elsif message.full_line =~ /Instruments Trace Error/i
      trigger(false, message.full_line.split(' : ')[1..-1].join)
    end

    # one time fatal
    first_time = "instruments: Instruments wants permission to analyze other processes. "
    first_time += "Please enter an administrator username and password to allow this."
    if message.full_line =~ /#{first_time}/
      trigger(true, "Instruments wants permission to analyze other processes.  Please run instruments manually to permit this.")
    end

  end

  def on_automation_finished
  end

end
