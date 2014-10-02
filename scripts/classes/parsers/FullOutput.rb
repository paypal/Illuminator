require 'rubygems'

####################################################################################################
# defaultParser
####################################################################################################

class FullOutput
  @stats
  def initialize
    @stats = {}
  end

  def addStatus (status)
    puts status.fullLine

    @stats[:total] = @stats[:total].to_i + 1 if status.status == :start
    @stats[status.status] = @stats[status.status].to_i + 1
  end

  def automationFinished(failed)

    if failed || failed?(@stats)
      STDERR.puts self.formatStatistics(@stats)
      STDERR.puts 'Tests failed, see log output for details'.red
    else
      STDOUT.puts self.formatStatistics(@stats)
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
