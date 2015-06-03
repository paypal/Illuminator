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
  attr_accessor :full_line
  attr_accessor :status
  attr_accessor :date
  attr_accessor :time
  attr_accessor :tz

  # parse lines in the form:    2014-10-20 20:43:41 +0000 Default: BLAH BLAH BLAH ACTUAL MESSAGE
  def self.from_line (line)
    parsed = line.match(/^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4}) ([^:]+): (.*)$/).to_a
    _, date_string, time_string, tz_string, status_string, msg_string = parsed

    message = ParsedInstrumentsMessage.new
    message.full_line = line
    message.message   = msg_string
    message.status    = parse_status(status_string)
    message.date      = date_string
    message.time      = time_string
    message.tz        = tz_string

    message
  end

  def self.parse_status(status)
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

  attr_accessor :app_location
  attr_accessor :hardware_id
  attr_accessor :sim_device
  attr_accessor :sim_language
  attr_accessor :attempts
  attr_accessor :startup_timeout

  attr_reader :started

  def initialize
    @listeners      = Hash.new
    @attempts       = 5
    @startup_timeout = 30
  end

  def add_listener (name, listener)
    @listeners[name] = listener
  end

  def cleanup
    dirs_to_remove = []
    build_artifact_keys = [:instruments]
    # get the directories without creating them (the 'true' arg), add them to our list
    build_artifact_keys.each do |key|
      dir = Illuminator::BuildArtifacts.instance.method(key).call(true)
      dirs_to_remove << dir
    end

    # remove directories in the list
    dirs_to_remove.each do |d|
      dir = Illuminator::HostUtils.realpath d
      puts "InstrumentsRunner cleanup: removing #{dir}"
      FileUtils.rmtree dir
    end
  end

  def start_detector_triggered
    @fully_started = true
  end

  def intermittent_failure_detector_triggered message
    @fully_started = true
    force_stop("Detected an intermittent failure condition - " + message)
  end

  def force_stop why
    puts "\n #{why}".red
    @should_abort = true
  end

  # Build the proper command and run it
  def run_once saltinel
    report_path = Illuminator::BuildArtifacts.instance.instruments

    # add saltinel listener
    start_detector = StartDetector.new(saltinel)
    start_detector.event_sink = self
    add_listener("start_detector", start_detector)

    global_js_file = Illuminator::BuildArtifacts.instance.illuminator_js_runner
    xcode_path     = Illuminator::XcodeUtils.instance.get_xcode_path
    template_path  = Illuminator::XcodeUtils.instance.get_instruments_template_path

    command = "env DEVELOPER_DIR='#{xcode_path}' /usr/bin/instruments"
    if !@hardware_id.nil?
      command << " -w '" + @hardware_id + "'"
    elsif !@sim_device.nil?
      command << " -w '" + @sim_device + "'"
    end

    command << " -t '#{template_path}' "
    command << "'#{@app_location}'"
    command << " -e UIASCRIPT '#{global_js_file}'"
    command << " -e UIARESULTSPATH '#{report_path}'"

    command << " #{@sim_language}" if @sim_language

    directory = Dir.pwd
    ret = nil
    # change directories and successfully change back
    begin
      Dir.chdir(report_path)
      ret = run_instruments_command command
    ensure
      Dir.chdir(directory)
    end
    return ret
  end


  # kill the instruments child process
  def kill_instruments(r, w, pid)
    puts "killing Instruments (pid #{pid})...".red
    begin
      Process.kill(9, pid)
      w.close
      r.close
      Process.wait(pid)
    rescue PTY::ChildExited
    end
  end

  # Run an instruments command until it looks like it started successfully or failed non-intermittently
  def run_instruments_command (command)
    @fully_started = false
    @should_abort  = false
    puts command.green
    remaining_attempts = @attempts

    # launch & re-launch instruments until it triggers the StartDetector
    while (not @fully_started) && remaining_attempts > 0 do
      successful_run = true
      remaining_attempts = remaining_attempts - 1
      puts "\nRelaunching instruments.  #{remaining_attempts} retries left".red unless (remaining_attempts + 1) == @attempts

      # spawn process and catch unexpected exits
      begin
        PTY.spawn(*command) do |r, w, pid|

          done_reading_output = false
          # select on the output and send it to the listeners
          while not done_reading_output do
            if @should_abort
              successful_run = false
              done_reading_output = true
              kill_instruments(r, w, pid)

            elsif IO.select([r], nil, nil, @startup_timeout) then
              line = r.readline.rstrip
              @listeners.each { |_, listener| listener.receive(ParsedInstrumentsMessage.from_line(line)) }
              if line =~ /Instruments Trace Error/i
                successful_run = false
                done_reading_output = true
              end
            elsif not @fully_started
              successful_run = false
              done_reading_output = true
              puts "\n Timeout #{@startup_timeout} reached without any output - ".red
              kill_instruments(r, w, pid)
              puts "killing simulator processes...".red
              Illuminator::XcodeUtils.kill_all_simulator_processes
              # TODO: might be necessary to delete any app crashes at this point
            else
              # We failed to get output for @startuptTimeout, but that's probably OK since we've successfully started
              # TODO: if we need to enforce a maximum time spent without output, this is where the counter would go
            end
          end
        end

      rescue EOFError
        # normal termination
      rescue Errno::ECHILD, Errno::EIO, PTY::ChildExited
        STDERR.puts 'Instruments exited unexpectedly'
        if @fully_started
          successful_run = false
          done_reading_output = true
        end
      ensure
        @listeners.each { |_, listener| listener.on_automation_finished }
      end
    end

    return successful_run
  end

end
