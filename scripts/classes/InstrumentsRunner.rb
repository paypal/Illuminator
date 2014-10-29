require 'rubygems'
require 'fileutils'
require 'colorize'
require 'pty'

require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/FullOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/JunitOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')


####################################################################################################
# status
####################################################################################################

class ParsedInstrumentsMessage

  attr_accessor :message
  attr_accessor :fullLine
  attr_accessor :status
  attr_accessor :date
  attr_accessor :time
  attr_accessor :tz

  # parse lines in the form:    2014-10-20 20:43:41 +0000 Default: BLAH BLAH BLAH ACTUAL MESSAGE
  def self.fromLine (line)
    parsed = line.match(/^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4}) ([^:]+): (.*)$/).to_a
    _, dateString, timeString, tzString, statusString, msgString = parsed

    message = ParsedInstrumentsMessage.new
    message.fullLine = line
    message.message  = msgString
    message.status   = self.parseStatus(statusString)
    message.date     = dateString
    message.time     = timeString
    message.tz       = tzString

    message
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
  attr_accessor :appLocation
  attr_accessor :hardwareID
  attr_accessor :simDevice
  attr_accessor :simLanguage
  attr_accessor :attempts
  attr_accessor :startupTimeout

  def initialize
    @listeners = Array.new
  end


  def cleanup
    dirsToRemove = []
    buildArtifactKeys = [:instruments]
    # get the directories without creating them (the 'true' arg), add them to our list
    buildArtifactKeys.each do |key|
      dir = BuildArtifacts.instance.method(key).call(true)
      dirsToRemove << dir
    end

    # remove directories in the list
    dirsToRemove.each do |dir|
      puts "InstrumentsRunner cleanup: removing #{dir}"
      FileUtils.rmtree dir
    end

  end


  def runOnce
    reportPath = BuildArtifacts.instance.instruments
    @listeners.push FullOutput.new
    @listeners.push JunitOutput.new BuildArtifacts.instance.junitReportFile

    @startupTimeout = 30
    @attempts = 30

    globalJSFile = BuildArtifacts.instance.illuminatorJsRunner

    xcodePath    = XcodeUtils.instance.getXcodePath
    templatePath = XcodeUtils.instance.getInstrumentsTemplatePath

    command = "env DEVELOPER_DIR='#{xcodePath}' /usr/bin/instruments"
    if hardwareID
      command << " -w '" + @hardwareID + "'"
    elsif simDevice
      command << " -w '" + @simDevice + "'"
    end

    command << " -t '#{templatePath}' "
    command << "'#{@appLocation}'"
    command << " -e UIASCRIPT '#{globalJSFile}'"
    command << " -e UIARESULTSPATH '#{reportPath}'"
    # TODO: either make the reporting conditional, or remove the option from AutomationArgumentParserFactory

    command << " #{@simLanguage}" if @simLanguage
    Dir.chdir(reportPath)
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
              @listeners.each { |listener| listener.receive(ParsedInstrumentsMessage.fromLine(line)) }
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
        @listeners.each { |listener| listener.onAutomationFinished failed }
        exit 1 if failed
      end
    end

  end

end
