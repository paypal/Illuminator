require 'fileutils'
require 'find'
require 'pathname'
require 'json'

require_relative './instruments-runner'
require_relative './javascript-runner'
require_relative './host-utils'
require_relative './xcode-utils'
require_relative './build-artifacts'
require_relative './test-suite'
require_relative './test-definitions'

require_relative 'listeners/pretty-output'
require_relative 'listeners/full-output'
require_relative 'listeners/console-logger'
require_relative 'listeners/test-listener'
require_relative 'listeners/saltinel-agent'

####################################################################################################
# runner
####################################################################################################


# responsibilities:
#  - apply options to relevant components
#  - prepare javascript config, and start instruments
#  - process any crashes
#  - run coverage
class AutomationRunner
  include SaltinelAgentEventSink
  include TestListenerEventSink

  attr_accessor :app_name
  attr_accessor :app_location

  attr_reader :instruments_runner
  attr_reader :javascript_runner

  def initialize
    @test_defs           = nil
    @test_suite          = nil
    @current_test        = nil
    @restarted_tests     = nil
    @stack_trace_lines   = nil
    @stack_trace_record  = false
    @app_crashed         = false
    @instruments_stopped = false
    @javascript_runner   = JavascriptRunner.new
    @instruments_runner  = InstrumentsRunner.new

    @instruments_runner.add_listener("consolelogger", ConsoleLogger.new)
  end


  def cleanup
    # start a list of what to remove
    dirs_to_remove = []

    # FIXME: this should probably get moved to instrument runner
    # keys to the methods of the BuildArtifacts singleton that we want to remove
    build_artifact_keys = [:crash_reports, :instruments, :object_files, :coverage_report_file,
                         :junit_report_file, :illuminator_js_runner, :illuminator_js_environment, :illuminator_config_file]
    # get the directories without creating them (the 'true' arg), add them to our list
    build_artifact_keys.each do |key|
      dir = Illuminator::BuildArtifacts.instance.method(key).call(true)
      dirs_to_remove << dir
    end

    # remove directories in the list
    dirs_to_remove.each do |d|
      dir = Illuminator::HostUtils.realpath d
      puts "AutomationRunner cleanup: removing #{dir}"
      FileUtils.rmtree dir
    end

    # run cleanups for variables we own
    @instruments_runner.cleanup
    # TODO: @javascript_runner cleanup?

  end


  def saltinel_agent_got_scenario_definitions jsonPath
    return unless @test_defs.nil?
    @test_defs = TestDefinitions.new jsonPath
  end


  def saltinel_agent_got_scenario_list jsonPath
    return unless @test_suite.nil?
    @restarted_tests = {}
    raw_list = JSON.parse( IO.read(jsonPath) )

    # create a test suite, and add test cases to it.  look up class names from test defs
    @test_suite = TestSuite.new(@implementation)
    raw_list["scenarioNames"].each do |n|
      test = @test_defs.by_name(n)
      test_file_name = test["inFile"]
      test_fn_name   = test["definedBy"]
      class_name     = test_file_name.sub(".", "_") + "." + test_fn_name
      @test_suite.add_test_case(class_name, n)
    end
    save_junit_test_report
  end

  def saltinel_agent_got_restart_request
    puts "ILLUMINATOR FAILURE TO ORGANIZE".red if @test_suite.nil?
    puts "ILLUMINATOR FAILURE TO ORGANIZE 2".red if @current_test.nil?
    if @restarted_tests[@current_test]
      puts "Denying restart request for previously-restarted scenario '#{@current_test}'".yellow
    else
      @test_suite[@current_test].reset!
      @restarted_tests[@current_test] = true
      @current_test = nil
      @instruments_runner.force_stop "Got restart request"
    end
  end

  def saltinel_agent_got_stacktrace_hint
    @stack_trace_record = true
  end

  def test_listener_got_test_start name
    @test_suite[@current_test].error "ILLUMINATOR FAILURE TO LISTEN" unless @current_test.nil?
    @test_suite[name].reset!
    @test_suite[name].start!
    @current_test = name
    @stack_trace_record = false
    @stack_trace_lines = Array.new
  end

  def test_listener_got_test_pass name
    puts "ILLUMINATOR FAILURE TO SORT TESTS".red unless name == @current_test
    @test_suite[name].pass!
    @current_test = nil
    save_junit_test_report
  end

  def test_listener_got_test_fail message
    if @test_suite.nil?
      puts "Failure before test suite was received: #{message}".red
      return
    elsif @current_test.nil?
      puts "Failure outside of a test: #{message}".red
    elsif message == "The target application appears to have died"
      @test_suite[@current_test].error message
      @app_crashed = true
      # The test runner loop will take it from here
    else
      @test_suite[@current_test].fail message
      @test_suite[@current_test].stacktrace = @stack_trace_lines.join("\n")
      @current_test = nil
      save_junit_test_report
    end
  end

  def test_listener_got_test_error message
    return if @test_suite.nil?
    return if @current_test.nil?
    @test_suite[@current_test].fail message
    @test_suite[@current_test].stacktrace = @stack_trace_lines.join("\n")
    @current_test = nil
    save_junit_test_report
  end

  def test_listener_got_line(status, message)
    return if @test_suite.nil? or @current_test.nil?
    line = message
    line = "#{status}: #{line}" unless status.nil?
    @test_suite[@current_test] << line
    @stack_trace_lines         << line if @stack_trace_record
  end

  def save_junit_test_report
    f = File.open(Illuminator::BuildArtifacts.instance.junit_report_file, 'w')
    f.write(@test_suite.to_xml)
    f.close
  end

  def run_annotated_command(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
      io.each {||}
    end
  end

  # translate input options into javascript config
  def configure_javascript_runner(options, target_device_id)
    js_config = @javascript_runner

    js_config.target_device_id     = target_device_id
    js_config.is_hardware          = !(options.illuminator.hardware_id.nil?)
    js_config.implementation       = options.javascript.implementation
    js_config.test_path            = options.javascript.test_path

    js_config.entry_point          = options.illuminator.entry_point
    js_config.scenario_list        = options.illuminator.test.names
    js_config.tags_any             = options.illuminator.test.tags.any
    js_config.tags_all             = options.illuminator.test.tags.all
    js_config.tags_none            = options.illuminator.test.tags.none
    js_config.random_seed          = options.illuminator.test.random_seed

    js_config.sim_device           = options.simulator.device
    js_config.sim_version          = options.simulator.version

    js_config.app_specific_config  = options.javascript.app_specific_config

    # don't offset the numbers this time
    js_config.scenario_number_offset = 0

    # write main config
    js_config.write_configuration()
  end


  def configure_javascript_rerunner(scenarios_to_run, number_offset)
    js_config                        = @javascript_runner
    js_config.random_seed            = nil
    js_config.entry_point            = "runTestsByName"
    js_config.scenario_list          = scenarios_to_run
    js_config.scenario_number_offset = number_offset

    js_config.write_configuration()
  end


  def configure_instruments_runner_listeners(options)
    test_listener = TestListener.new
    test_listener.event_sink = self
    @instruments_runner.add_listener("test_listener", test_listener)

    # listener to provide screen output
    if options.instruments.do_verbose
      @instruments_runner.add_listener("consoleoutput", FullOutput.new)
    else
      @instruments_runner.add_listener("consoleoutput", PrettyOutput.new)
    end
  end

  def configure_instruments_runner(options)
    # set up instruments and get target device ID
    @instruments_runner.startup_timeout = options.instruments.timeout
    @instruments_runner.hardware_id     = options.illuminator.hardware_id
    @instruments_runner.app_location    = @app_location

    if options.illuminator.hardware_id.nil?
      @instruments_runner.sim_language  = options.simulator.language
      @instruments_runner.sim_device    = Illuminator::XcodeUtils.instance.get_simulator_id(options.simulator.device,
                                                                                            options.simulator.version)
    end

    # max silence is the timeout times 5 unless otherwise specified
    @instruments_runner.max_silence = options.instruments.max_silence
    @instruments_runner.max_silence ||= options.instruments.timeout * 5

    # setup listeners on instruments
    configure_instruments_runner_listeners(options)
  end

  def configure_target_device(options)
    unless options.illuminator.hardware_id.nil?
      puts "Using hardware_id = '#{options.illuminator.hardware_id}' instead of simulator".green
      target_device_id = options.illuminator.hardware_id
    else
      if @instruments_runner.sim_device.nil?
        msg = "Could not find a simulator for device='#{options.simulator.device}', version='#{options.simulator.version}'"
        puts msg.red
        puts Illuminator::XcodeUtils.instance.get_simulator_devices.yellow
        raise ArgumentError, msg
      end
      target_device_id = @instruments_runner.sim_device
    end

    # reset the simulator if desired
    Illuminator::XcodeUtils.kill_all_simulator_processes
    if options.illuminator.hardware_id.nil? and options.illuminator.task.set_sim
      Illuminator::XcodeUtils.instance.reset_simulator target_device_id
    end

    target_device_id
  end

  def run_with_options(options)

    # Sanity checks
    raise ArgumentError, 'Entry point was not supplied'       if options.illuminator.entry_point.nil?
    raise ArgumentError, 'Path to all tests was not supplied' if options.javascript.test_path.nil?
    raise ArgumentError, 'Implementation was not supplied'    if options.javascript.implementation.nil?

    @app_name        = options.xcode.app_name
    @app_location    = options.instruments.app_location
    @implementation  = options.javascript.implementation

    # set up instruments and get target device ID
    configure_instruments_runner(options)
    target_device_id = configure_target_device(options)

    start_time = Time.now
    @test_suite = nil

    # run the first time
    instruments_exit_status = execute_entire_test_suite(options, target_device_id, nil)

    # rerun if specified.  do not rerun if @testsuite wasn't received (indicating setup problems)
    if instruments_exit_status.fatal_error
      puts "Fatal error: #{instruments_exit_status.fatal_reason}".red
    elsif options.illuminator.test.retest.attempts.nil? or @test_suite.nil?
      # nothing to do
    else
      execute_test_suite_reruns(options, target_device_id)
    end

    # annotate the run
    total_time = Time.at(Time.now - start_time).gmtime.strftime("%H:%M:%S")
    puts "Automation completed in #{total_time}".green

    perform_coverage(options)

    Illuminator::XcodeUtils.kill_all_simulator_processes if options.simulator.kill_after

    # summarize test results to the console if desired
    if "describe" == options.illuminator.entry_point
      return true       # no tests needed to run
    else
      summarize_test_results @test_suite
    end

    save_failed_tests_config(options, @test_suite.unpassed_tests) unless @test_suite.nil?

    # TODO: exit code should be an integer, and each of these should be cases
    return false if @test_suite.nil?                        # no tests were received
    return false if 0 == @test_suite.passed_tests.length    # no tests passed, or none ran
    return false if 0 < @test_suite.unpassed_tests.length   # 1 or more tests failed
    return true
  end

  # perform coverage if desired and possible
  def perform_coverage(options)
    unless @test_suite.nil?
      if options.illuminator.task.coverage #TODO: only if there are no crashes?
        if Illuminator::HostUtils.which("gcovr").nil?
          puts "Skipping requested coverage generation because gcovr does not appear to be in the PATH".yellow
        else
          generate_coverage Dir.pwd
        end
      end
    end
  end

  # This function is for preventing infinite loops in the test run that could be caused by (e.g.)
  #  - an instruments max_silence error that happens ever time.
  def handle_unsuccessful_instruments_run
    return if @test_suite.nil?
    return if @current_test.nil?

    if @restarted_tests[@current_test]
      @test_suite[@current_test].error("Illuminator could not get this test to complete")
      save_junit_test_report
      @current_test = nil
    else
      @restarted_tests[@current_test] = true
    end
  end


  # run a test suite, restarting if necessary
  def execute_entire_test_suite(options, target_device_id, specific_tests)

    # loop until all test cases are covered.
    # we won't get the actual test list until partway through -- from a listener callback
    exit_status = nil
    begin
      remove_any_app_crashes
      @app_crashed = false
      @instruments_stopped = false

      # Setup javascript to run the appropriate list of tests (initial or leftover)
      if @test_suite.nil?
        # very first attempt
        configure_javascript_runner(options, target_device_id)
      elsif specific_tests.nil?
        # not first attempt, but we haven't made it all the way through yet
        configure_javascript_rerunner(@test_suite.unstarted_tests, @test_suite.finished_tests.length)
      else
        # we assume that we've already gone through and have been given specific tests to check out
        configure_javascript_rerunner(specific_tests, 0)
      end

      # Setup new saltinel listener (will overwrite the old one if it exists)
      agent_listener = SaltinelAgent.new(@javascript_runner.saltinel)
      agent_listener.event_sink = self
      @instruments_runner.add_listener("saltinelAgent", agent_listener)

      exit_status = @instruments_runner.run_once(@javascript_runner.saltinel)

      if @app_crashed
        handle_app_crash
      elsif !exit_status.normal
        handle_unsuccessful_instruments_run
      end

    end while not (@test_suite.nil? or @test_suite.unstarted_tests.empty? or exit_status.fatal_error)
    # as long as we have a test suite with unfinished tests, and no fatal errors, keep going

    exit_status
  end


  def execute_test_suite_reruns(options, target_device_id)
    # retry any failed tests
    for att in 1..options.illuminator.test.retest.attempts
      unpassed_tests = @test_suite.unpassed_tests.map { |t| t.name }

      # run them in batch mode if desired
      unless options.illuminator.test.retest.solo
        puts "Retrying failed tests in batch, attempt #{att} of #{options.illuminator.test.retest.attempts}"
        execute_entire_test_suite(options, target_device_id, unpassed_tests)
      else
        puts "Retrying failed tests individually, attempt #{att} of #{options.illuminator.test.retest.attempts}"

        unpassed_tests.each_with_index do |t, index|
          test_num = index + 1
          puts "Solo attempt for test #{test_num} of #{unpassed_tests.length}"
          execute_entire_test_suite(options, target_device_id, [t])
        end
      end
    end
  end


  # print a summary of the tests that ran, in the form ..........!.!!.!...!..@...@.!
  #  where periods are passing tests, exclamations are fails, and '@' symbols are crashes
  def summarize_test_results test_suite
    if test_suite.nil?
      puts "No test cases were received from the Javascript environment; check logs for possible setup problems.".red
      return
    end

    all_tests      = test_suite.all_tests
    unpassed_tests = test_suite.unpassed_tests

    if 0 == all_tests.length
      puts "No tests ran".yellow
    elsif 0 < unpassed_tests.length
      result = "Result: "
      all_tests.each do |t|
        if not t.ran?
          result << "-"
        elsif t.failed?
          result << "!"
        elsif t.errored?
          result << "@"
        else
          result << "."
        end
      end
      puts result.red
      puts "#{unpassed_tests.length} of #{all_tests.length} tests FAILED".red   # failed in the test suite sense
    else
      puts "All #{all_tests.length} tests PASSED".green
    end

  end

  def save_failed_tests_config(options, failed_tests)
    return unless 0 < failed_tests.length

    # save options to re-run failed tests
    new_options = options.dup
    new_options.illuminator.test.random_seed = nil
    new_options.illuminator.entry_point      = "runTestsByName"
    new_options.illuminator.test.names       = failed_tests.map { |t| t.name }

    Illuminator::HostUtils.save_json(new_options.to_h,
                                     Illuminator::BuildArtifacts.instance.illuminator_rerun_failed_tests_settings)
  end

  def remove_any_app_crashes()
    Dir.glob("#{Illuminator::XcodeUtils.instance.get_crash_directory}/#{@app_name}*.crash").each do |crash_path|
      FileUtils.rmtree crash_path
    end
  end


  def handle_app_crash
    # tell the current test suite about any failures
    if @current_test.nil?
      puts "ILLUMINATOR FAILURE TO HANDLE APP CRASH"
      return
    end

    # assume a crash report exists, and look for it
    crashes = report_any_app_crashes

    # write something useful depending on what crash reports are found
    case crashes.keys.length
    when 0
      d = Illuminator::XcodeUtils.instance.get_crash_directory
      stacktrace_text = "No crash reports found in #{d}, perhaps the app exited cleanly instead"
    when 1
      stacktrace_text = crashes[crashes.keys[0]]
    else
      stacktrace_body = crashes[crashes.keys[0]]
      stacktrace_text = "Found multiple crashes: #{crashes.keys}  Here is the first one:\n\n #{stacktrace_body}"
    end

    @test_suite[@current_test].stacktrace = stacktrace_text
    @current_test = nil
    save_junit_test_report
  end



  def report_any_app_crashes()
    crash_reports_path = Illuminator::BuildArtifacts.instance.crash_reports
    FileUtils.mkdir_p crash_reports_path unless File.directory?(crash_reports_path)

    crashes = Hash.new
    # TODO: glob if @app_name is nil
    Dir.glob("#{Illuminator::XcodeUtils.instance.get_crash_directory}/#{@app_name}*.crash").each do |crash_path|
      # TODO: extract process name and ignore ["launchd_sim", ...]

      puts "Found a crash report from this test run at #{crash_path}"
      crash_name = File.basename(crash_path, ".crash")
      crash_report_path = "#{crash_reports_path}/#{crash_name}.crash"
      crash_text = []
      if Illuminator::XcodeUtils.instance.create_symbolicated_crash_report(@app_location, crash_path, crash_report_path)
        puts "Created a symbolicated version of the crash report at #{crash_report_path}".red
      else
        FileUtils.cp(crash_path, crash_report_path)
        puts "Copied the crash report (assumed already symbolicated) to #{crash_report_path}".red
      end

      # get the first few lines for the log
      # TODO: possibly do error handling here just in case the file doesn't exist
      file = File.open(crash_report_path, 'rb')
      file.each do |line|
        break if line.match(/^Binary Images/)
        crash_text << line
      end
      file.close

      crash_text << "\n"
      crash_text << "Full crash report saved at #{crash_report_path}"

      crashes[crash_name] = crash_text.join("")
    end
    crashes
  end


  def generate_coverage(gcWorkspace)
    destination_file      = Illuminator::BuildArtifacts.instance.coverage_report_file
    xcode_artifacts_folder = Illuminator::BuildArtifacts.instance.xcode
    destination_path      = Illuminator::BuildArtifacts.instance.object_files

    exclude_regex = '.*(Debug|contrib).*'
    puts "Generating automation test coverage to #{destination_file}".green
    sleep (3) # TODO: we are waiting for the app process to complete, maybe do this a different way

    # cleanup
    FileUtils.rm destination_file, :force => true

    # we copy all the relevant build artifacts for coverage into a second folder.  we may not need to do this.
    file_paths = []
    Find.find(xcode_artifacts_folder) do |pathP|
      path = pathP.to_s
      if /.*\.gcda$/.match path
        file_paths << path
        path_without_ext = path.chomp(File.extname(path))

        file_paths << path_without_ext + '.d'
        file_paths << path_without_ext + '.dia'
        file_paths << path_without_ext + '.o'
        file_paths << path_without_ext + '.gcno'
      end
    end

    file_paths.each do |path|
      FileUtils.cp path, destination_path
    end

    command = "gcovr -r '#{gcWorkspace}' --exclude='#{exclude_regex}' --xml '#{destination_path}' > '#{destination_file}'"
    run_annotated_command(command)

  end
end
