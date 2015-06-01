
require_relative './instruments-listener'

# A listener class that just looks for saltinel messages and parses them,
#  sending them off to a subclassable handler
class SaltinelListener < InstrumentsListener

  def initialize saltinel
    @saltinel = saltinel
    on_init
  end

  def on_init
  end

  def receive (message)
    unsalted = /^#{@saltinel} (.*) #{@saltinel}/.match(message.message)
    on_saltinel(unsalted.to_a[1]) unless unsalted.nil?
  end

  def on_saltinel inner_message
    puts "CAUGHT SALTINEL MESSAGE in #{self.class.name}.on_saltinel".red
    puts inner_message.green
  end

end
