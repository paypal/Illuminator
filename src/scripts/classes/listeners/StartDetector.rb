
require File.join(File.expand_path(File.dirname(__FILE__)), 'SaltinelListener.rb')

module StartDetectorEventSink

  def startDetectorTriggered
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# StartDetector monitors the logs for things that indicate a successful startup of instruments
#  - the saltinel for the intended test list
#  - a javascript error
#  - etc
class StartDetector < SaltinelListener

  attr_accessor :eventSink

  def onInit
    @alreadyStarted = false
  end

  def trigger
    # assume developer has set eventSink already
    @eventSink.startDetectorTriggered unless @alreadyStarted
    @alreadyStarted = true
  end

  def receive message
    super # run the SaltinelListener processor

    # error cases that indicate successful start but involve errors that won't be fixed by a restart
    self.trigger if :error == message.status and /Script threw an uncaught JavaScript error:/ =~ message.message
    self.trigger if /^Instruments Usage Error :/ =~ message.fullLine
  end

  def onSaltinel innerMessage
    self.trigger if /Saved intended test list to/ =~ innerMessage
    self.trigger if /Successful launch/ =~ innerMessage
  end

  def onAutomationFinished
  end

end
