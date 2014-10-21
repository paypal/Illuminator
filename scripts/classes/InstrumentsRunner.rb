require 'rubygems'
require 'fileutils'
require 'colorize'
require 'pty'

require File.join(File.expand_path(File.dirname(__FILE__)), 'parsers/FullOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'parsers/JunitOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')


####################################################################################################
# status
####################################################################################################

class Status

  attr_accessor :message
  attr_accessor :fullLine
  attr_accessor :status
  attr_accessor :date
  attr_accessor :time
  attr_accessor :tz

  # parse lines in the form:    2014-10-20 20:43:41 +0000 Default: BLAH BLAH BLAH ACTUAL MESSAGE
  def self.statusWithLine (line)
    parsed = line.match(/^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4}) ([^:]+): (.*)$/).to_a
    _, dateString, timeString, tzString, statusString, msgString = parsed

    status = Status.new
    status.fullLine = line
    status.message =  msgString
    status.status =   self.parseStatus(statusString)
    status.date =     dateString
    status.time =     timeString
    status.tz =       tzString

    status
  end

  def self.parseStatus(status)
    case status
      when /start/i    then :start
      when /pass/i     then :pass
      when /fail/i     then :fail
      when /error/i    then :error
      when /warning/i  then :warning
      when /issue/i    then :issue
      when /default/i  then :default
      when /debug/i    then :debug
      else :unknown
    end
  end

end

####################################################################################################
# command builder
####################################################################################################

class InstrumentsRunner
  attr_accessor :buildArtifacts
  attr_accessor :xcodePath
  attr_accessor :appLocation
  attr_accessor :reportPath
  attr_accessor :hardwareID
  attr_accessor :simDevice
  attr_accessor :simLanguage
  attr_accessor :attempts
  attr_accessor :startupTimeout

  @parsers

  def initialize
    @parsers = Array.new
  end


  def start
    junitReportPath = @reportPath + '/testAutomatically.xml'
    @parsers.push FullOutput.new
    @parsers.push JunitOutput.new junitReportPath

    @startupTimeout = 30
    @attempts = 30
    testCase = "#{@buildArtifacts}/testAutomatically.js"

    templatePath = XcodeUtils.getInstrumentsTemplatePath(@xcodePath)

    command = "env DEVELOPER_DIR='#{@xcodePath}' /usr/bin/instruments"
    if hardwareID
      command << " -w '" + @hardwareID + "'"
    elsif simDevice
      command << " -w '" + @simDevice + "'"
    end

    command << " -t '#{templatePath}' "
    command << "'#{@appLocation}'"
    command << " -e UIASCRIPT '#{testCase}'"
    command << " -e UIARESULTSPATH '#{@reportPath}'"

    command << " #{@simLanguage}" if @simLanguage
    Dir.chdir(@reportPath)
    self.runCommand command
  end


  def runCommand (command)
    puts command.green
    started = false
    remaining_attempts = @attempts

    while (not started) && remaining_attempts > 0 do
      failed = false
      remaining_attempts = remaining_attempts - 1
      warn "\n Launching instruments.  #{remaining_attempts} retries left".red

      begin
        PTY.spawn(*command) do |r, w, pid|
          while not failed do
            if IO.select([r], nil, nil, @startupTimeout) then
              line = r.readline.rstrip
              if (line.include? ' +0000 ') && (not line.include? ' +0000 Fail: The target application appears to have died') then
                started = true
              end
              @parsers.each { |output|
                output.addStatus(Status.statusWithLine(line))
              }
              failed = true if line =~ /Instruments Trace Error/i
            else
              failed = true
              puts "\n Timeout #{options.timeout} reached without any output - ".red
              puts "killing Instruments (pid #{pid})...".red
              begin
                Process.kill(9, pid)
                w.close
                r.close
                Process.wait(pid)
              rescue PTY::ChildExited
              end
              puts "Pid #{pid} killed.".red
            end
          end
        end

      rescue Errno::EIO
      rescue Errno::ECHILD
      rescue EOFError
      rescue PTY::ChildExited
        STDERR.puts 'Instruments exited unexpectedly'
        exit 1 if started
      ensure
        @parsers.each { |output|
          output.automationFinished failed
        }
        exit 1 if failed
      end
    end

  end

end
