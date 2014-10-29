require 'rubygems'

####################################################################################################
# defaultParser
####################################################################################################

class FullOutput

  def initialize
    @lines = {}
  end

  def receive (message)
    puts message.fullLine

    @lines[:total] = @lines[:total].to_i + 1 if message.status == :start
    @lines[message.status] = @lines[message.status].to_i + 1
  end

  def onAutomationFinished(failed)

    if failed || failed?(@lines)
      STDERR.puts self.formatStatistics(@lines)
      STDERR.puts 'Tests failed, see log output for details'.red
    else
      STDOUT.puts self.formatStatistics(@lines)
      STDOUT.puts 'TEST PASSED'.green
    end
  end

  def failed?(statistics)
    statistics[:total].to_i == 0 || statistics[:fail].to_i > 0 || statistics[:error].to_i > 0
  end

  def formatStatistics(statistics)
    output = "#{statistics[:total].to_i} tests, #{statistics[:fail].to_i} failures".green
    output << ", #{statistics[:error].to_i} errors".red if statistics[:error].to_i > 0
    output << ", #{statistics[:warning].to_i} warnings".green if statistics[:warning].to_i > 0
    output << ", #{statistics[:issue].to_i} issues".green if statistics[:issue].to_i > 0
    output
  end
end
