
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

# A listener class that just looks for saltinel messages and parses them,
#  sending them off to a subclassable handler
class SaltinelListener < InstrumentsListener

  def initialize saltinel
    @saltinel = saltinel
    self.reset
  end

  def receive (message)
    unSalted = /^#{@saltinel} (.*) #{@saltinel}/.match(message.message)
    self.onSaltinel(unSalted.to_a[1]) unless unSalted.nil?
  end

  def onSaltinel innerMessage
    puts "CAUGHT SALTINEL MESSAGE in #{self.class.name}.onSaltinel".red
    puts innerMessage.green
  end

end
