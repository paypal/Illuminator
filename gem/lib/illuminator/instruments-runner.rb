require 'fileutils'
require 'colorize'
require 'pty'

require_relative './xcode-utils'
require_relative './build-artifacts'
require_relative 'listeners/start-detector'
require_relative 'listeners/intermittent-failure-detector'

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
      when /stopped/i  then :stopped
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
  include StartDetectorEventSink
  include IntermittentFailureDetectorEventSink

  attr_accessor :appLocation
  attr_accessor :hardwareID
  attr_accessor :simDevice
  attr_accessor :simLanguage
  attr_accessor :attempts
  attr_accessor :startupTimeout

  attr_reader :started

  def initialize
    @listeners      = Hash.new
    @attempts       = 5
    @startupTimeout = 30
  end

  def addListener (name, listener)
    @listeners[name] = listener
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
    dirsToRemove.each do |d|
      dir = HostUtils.realpath d
      puts "InstrumentsRunner cleanup: removing #{dir}"
      FileUtils.rmtree dir
    end
  end

  def startDetectorTriggered
    @fullyStarted = true
  end

  def intermittentFailureDetectorTriggered message
    @fullyStarted = true
    self.forceStop("Detected an intermittent failure condition - " + message)
  end

  def forceStop why
    puts "\n #{why}".red
    @shouldAbort = true
  end

  def runOnce saltinel
    reportPath = BuildArtifacts.instance.instruments

    # add saltinel listener
    startDetector = StartDetector.new(saltinel)
    startDetector.eventSink = self
    self.addListener("startDetector", startDetector)

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

    command << " #{@simLanguage}" if @simLanguage

    directory = Dir.pwd
    ret = nil
    # change directories and successfully change back
    begin
      Dir.chdir(reportPath)
      ret = self.runInstrumentsCommand command
    ensure
      Dir.chdir(directory)
    end
    return ret
  end


  def killInstruments(r, w, pid)
    puts "killing Instruments (pid #{pid})...".red
    begin
      Process.kill(9, pid)
      w.close
      r.close
      Process.wait(pid)
    rescue PTY::ChildExited
    end
  end


  def runInstrumentsCommand (command)
    @fullyStarted = false
    @shouldAbort  = false
    puts command.green
    remaining_attempts = @attempts

    # launch & re-launch instruments until it triggers the StartDetector
    while (not @fullyStarted) && remaining_attempts > 0 do
      successfulRun = true
      remaining_attempts = remaining_attempts - 1
      puts "\nRelaunching instruments.  #{remaining_attempts} retries left".red unless (remaining_attempts + 1) == @attempts

      # spawn process and catch unexpected exits
      begin
        PTY.spawn(*command) do |r, w, pid|

          doneReadingOutput = false
          # select on the output and send it to the listeners
          while not doneReadingOutput do
            if @shouldAbort
              successfulRun = false
              doneReadingOutput = true
              self.killInstruments(r, w, pid)

            elsif IO.select([r], nil, nil, @startupTimeout) then
              line = r.readline.rstrip
              @listeners.each { |_, listener| listener.receive(ParsedInstrumentsMessage.fromLine(line)) }
              if line =~ /Instruments Trace Error/i
                successfulRun = false
                doneReadingOutput = true
              end
            elsif not @fullyStarted
              successfulRun = false
              doneReadingOutput = true
              puts "\n Timeout #{@startupTimeout} reached without any output - ".red
              self.killInstruments(r, w, pid)
              puts "killing simulator processes...".red
              XcodeUtils.killAllSimulatorProcesses
              # TODO: might be necessary to delete any app crashes at this point
            else
              # We failed to get output for @startuptTimeout, but that's probably OK since we've successfully started
              # TODO: if we need to enforce a maximum time spent without output, this is where the counter would go
            end
          end
        end

      rescue Errno::EIO
      rescue Errno::ECHILD
      rescue EOFError
      rescue PTY::ChildExited
        STDERR.puts 'Instruments exited unexpectedly'
        if @fullyStarted
          successfulRun = false
          doneReadingOutput = true
        end
      ensure
        @listeners.each { |_, listener| listener.onAutomationFinished }
      end
    end

    return successfulRun
  end

end
