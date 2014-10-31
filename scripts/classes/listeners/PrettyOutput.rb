
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

class PrettyOutput < InstrumentsListener

  def receive (message)
    case message.status
    when :start
      puts "Start: #{message.message}".green
    when :pass
      puts "Pass: #{message.message}".green
      puts
    when :fail, :error, :issue
      puts "Fail: #{message.message}".red
    when :warning
      puts "Warn: #{message.message}".yellow
    when :default
      puts "      #{message.message}"
    end

  end

  def onAutomationFinished
  end

end
