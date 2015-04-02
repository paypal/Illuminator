require 'rubygems'
require 'fileutils'
require 'find'
require 'pathname'
require 'json'

require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'JavascriptRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'HostUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'TestSuite.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'TestDefinitions.rb')

require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/PrettyOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/FullOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/ConsoleLogger.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/TestListener.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/SaltinelAgent.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/StopDetector.rb')

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
  include StopDetectorEventSink

  attr_accessor :appName
  attr_accessor :workspace
  attr_accessor :appLocation

  attr_reader :instrumentsRunner
  attr_reader :javascriptRunner

  def initialize
    @testDefs           = nil
    @testSuite          = nil
    @currentTest        = nil
    @restartedTests     = nil
    @stackTraceLines    = nil
    @stackTraceRecord   = false
    @appCrashed         = false
    @instrumentsStopped = false
    @javascriptRunner   = JavascriptRunner.new
    @instrumentsRunner  = InstrumentsRunner.new

    @instrumentsRunner.addListener("consolelogger", ConsoleLogger.new)
  end


  def cleanup
    # start a list of what to remove
    dirsToRemove = []

    # FIXME: this should probably get moved to instrument runner
    # keys to the methods of the BuildArtifacts singleton that we want to remove
    buildArtifactKeys = [:crashReports, :instruments, :objectFiles, :coverageReportFile,
                         :junitReportFile, :illuminatorJsRunner, :illuminatorJsEnvironment, :illuminatorConfigFile]
    # get the directories without creating them (the 'true' arg), add them to our list
    buildArtifactKeys.each do |key|
      dir = BuildArtifacts.instance.method(key).call(true)
      dirsToRemove << dir
    end

    # remove directories in the list
    dirsToRemove.each do |d|
      dir = HostUtils.realpath d
      puts "AutomationRunner cleanup: removing #{dir}"
      FileUtils.rmtree dir
    end

    # run cleanups for variables we own
    @instrumentsRunner.cleanup
    # TODO: @javascriptRunner cleanup?

  end


  def saltinelAgentGotScenarioDefinitions jsonPath
    return unless @testDefs.nil?
    @testDefs = TestDefinitions.new jsonPath
  end


  def saltinelAgentGotScenarioList jsonPath
    return unless @testSuite.nil?
    @restartedTests = {}
    rawList = JSON.parse( IO.read(jsonPath) )

    # create a test suite, and add test cases to it.  look up class names from test defs
    @testSuite = TestSuite.new(@implementation)
    rawList["scenarioNames"].each do |n|
      test = @testDefs.byName(n)
      testFileName = test["inFile"]
      testFnName   = test["definedBy"]
      className    = testFileName.sub(".", "_") + "." + testFnName
      @testSuite.addTestCase(className, n)
    end
    self.saveJunitTestReport
  end

  def saltinelAgentGotRestartRequest
    puts "ILLUMINATOR FAILURE TO ORGANIZE".red if @testSuite.nil?
    puts "ILLUMINATOR FAILURE TO ORGANIZE 2".red if @currentTest.nil?
    if @restartedTests[@currentTest]
      puts "Denying restart request for previously-restarted scenario '#{@currentTest}'".yellow
    else
      @testSuite[@currentTest].reset!
      @restartedTests[@currentTest] = true
      @currentTest = nil
      @instrumentsRunner.forceStop "Got restart request"
    end
  end

  def saltinelAgentGotStacktraceHint
    @stackTraceRecord = true
  end

  def stopDetectorTriggered
    @instrumentsStopped = true
  end

  def testListenerGotTestStart name
    @testSuite[@currentTest].error "ILLUMINATOR FAILURE TO LISTEN" unless @currentTest.nil?
    @testSuite[name].reset!
    @testSuite[name].start!
    @currentTest = name
    @stackTraceRecord = false
    @stackTraceLines = Array.new
  end

  def testListenerGotTestPass name
    puts "ILLUMINATOR FAILURE TO SORT TESTS".red unless name == @currentTest
    @testSuite[name].pass!
    @currentTest = nil
    self.saveJunitTestReport
  end

  def testListenerGotTestFail message
    if @testSuite.nil?
      puts "Failure before test suite was received: #{message}".red
      return
    elsif @currentTest.nil?
      puts "Failure outside of a test: #{message}".red
    elsif message == "The target application appears to have died"
      @testSuite[@currentTest].error message
      @appCrashed = true
      # The test runner loop will take it from here
    else
      @testSuite[@currentTest].fail message
      @testSuite[@currentTest].stacktrace = @stackTraceLines.join("\n")
      @currentTest = nil
      self.saveJunitTestReport
    end
  end

  def testListenerGotTestError message
    return if @testSuite.nil?
    return if @currentTest.nil?
    @testSuite[@currentTest].fail message
    @testSuite[@currentTest].stacktrace = @stackTraceLines.join("\n")
    @currentTest = nil
    self.saveJunitTestReport
  end

  def testListenerGotLine(status, message)
    return if @testSuite.nil? or @currentTest.nil?
    line = message
    line = "#{status}: #{line}" unless status.nil?
    @testSuite[@currentTest] << line
    @stackTraceLines         << line if @stackTraceRecord
  end

  def saveJunitTestReport
    f = File.open(BuildArtifacts.instance.junitReportFile, 'w')
    f.write(@testSuite.to_xml)
    f.close
  end

  def runAnnotatedCommand(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
      io.each {||}
    end
  end

  # translate input options into javascript config
  def configureJavascriptRunner(options)
    jsConfig = @javascriptRunner

    jsConfig.implementation      = options.javascript.implementation
    jsConfig.testPath            = options.javascript.testPath

    jsConfig.entryPoint          = options.illuminator.entryPoint
    jsConfig.scenarioList        = options.illuminator.test.names
    jsConfig.tagsAny             = options.illuminator.test.tags.any
    jsConfig.tagsAll             = options.illuminator.test.tags.all
    jsConfig.tagsNone            = options.illuminator.test.tags.none
    jsConfig.randomSeed          = options.illuminator.test.randomSeed
    jsConfig.hardwareID          = options.illuminator.hardwareID

    jsConfig.simDevice           = options.simulator.device
    jsConfig.simVersion          = options.simulator.version

    jsConfig.appSpecificConfig   = options.javascript.appSpecificConfig

    # don't offset the numbers this time
    jsConfig.scenarioNumberOffset = 0

    # write main config
    jsConfig.writeConfiguration()
  end


  def configureJavascriptReRunner(scenariosToRun, numberOffset)
    jsConfig                      = @javascriptRunner
    jsConfig.randomSeed           = nil
    jsConfig.entryPoint           = "runTestsByName"
    jsConfig.scenarioList         = scenariosToRun
    jsConfig.scenarioNumberOffset = numberOffset

    jsConfig.writeConfiguration()
  end


  def runWithOptions(options)
    gcovrWorkspace = Dir.pwd

    # Sanity checks
    raise ArgumentError, 'Entry point was not supplied'       if options.illuminator.entryPoint.nil?
    raise ArgumentError, 'Path to all tests was not supplied' if options.javascript.testPath.nil?
    raise ArgumentError, 'Implementation was not supplied'    if options.javascript.implementation.nil?

    @appName        = options.xcode.appName
    @appLocation    = options.instruments.appLocation
    @implementation = options.javascript.implementation

    # set up instruments
    @instrumentsRunner.startupTimeout = options.instruments.timeout
    @instrumentsRunner.hardwareID     = options.illuminator.hardwareID
    @instrumentsRunner.appLocation    = @appLocation
    if options.illuminator.hardwareID.nil?
      @instrumentsRunner.simLanguage  = options.simulator.language
      @instrumentsRunner.simDevice    = XcodeUtils.instance.getSimulatorID(options.simulator.device,
                                                                           options.simulator.version)
      if @instrumentsRunner.simDevice.nil?
        puts "Could not find a simulator for device='#{options.simulator.device}', version='#{options.simulator.version}'".red
        puts XcodeUtils.instance.getSimulatorDevices.yellow
        return false
      end
    else
      puts "Using hardwareID = '#{options.illuminator.hardwareID}' instead of simulator".green
    end

    # setup listeners on instruments
    testListener = TestListener.new
    testListener.eventSink = self
    @instrumentsRunner.addListener("testListener", testListener)

    stopDetector = StopDetector.new
    stopDetector.eventSink = self
    @instrumentsRunner.addListener("stopDetector", stopDetector)


    # listener to provide screen output
    if options.instruments.doVerbose
      @instrumentsRunner.addListener("consoleoutput", FullOutput.new)
    else
      @instrumentsRunner.addListener("consoleoutput", PrettyOutput.new)
    end

    XcodeUtils.killAllSimulatorProcesses
    XcodeUtils.resetSimulator if options.illuminator.hardwareID.nil? and options.illuminator.task.setSim

    startTime = Time.now

    @testSuite = nil

    # run the first time
    self.executeEntireTestSuite(options, nil)

    unless options.illuminator.test.retest.attempts.nil?
      # retry any failed tests
      for i in 0..(options.illuminator.test.retest.attempts - 1)
        att = i + 1
        unPassedTests = @testSuite.unPassedTests.map { |t| t.name }

        # run them in batch mode if desired
        unless options.illuminator.test.retest.solo
          puts "Retrying failed tests in batch, attempt #{att} of #{options.illuminator.test.retest.attempts}"
          self.executeEntireTestSuite(options, unPassedTests)
        else
          puts "Retrying failed tests individually, attempt #{att} of #{options.illuminator.test.retest.attempts}"

          unPassedTests.each_with_index do |t, index|
            testNum = index + 1
            puts "Solo attempt for test #{testNum} of #{unPassedTests.length}"
            self.executeEntireTestSuite(options, [t])
          end
        end
      end
    end

    totalTime = Time.at(Time.now - startTime).gmtime.strftime("%H:%M:%S")
    puts "Automation completed in #{totalTime}".green


    # DONE LOOPING
    unless @testSuite.nil?
      if options.illuminator.task.coverage #TODO: only if there are no crashes?
        if HostUtils.which("gcovr").nil?
          puts "Skipping requested coverage generation because gcovr does not appear to be in the PATH".yellow
        else
          self.generateCoverage gcovrWorkspace
        end
      end
      self.saveFailedTestsConfig(options, @testSuite.unPassedTests)
    end

    XcodeUtils.killAllSimulatorProcesses if options.simulator.killAfter

    if "describe" == options.illuminator.entryPoint
      return true       # no tests needed to run
    else
      self.summarizeTestResults @testSuite
    end

    # TODO: exit code should be an integer, and each of these should be cases
    return false if @testSuite.nil?                         # no tests were received
    return false if 0 == @testSuite.passedTests.length      # no tests passed, or none ran
    return false if 0 < @testSuite.unPassedTests.length     # 1 or more tests failed
    return true
  end

  # run a test suite, restarting if necessary
  def executeEntireTestSuite(options, specificTests)

    # loop until all test cases are covered.
    # we won't get the actual test list until partway through -- from a listener callback
    begin
      self.removeAnyAppCrashes
      @appCrashed = false
      @instrumentsStopped = false

      # Setup javascript to run the appropriate list of tests (initial or leftover)
      if @testSuite.nil?
        # very first attempt
        self.configureJavascriptRunner options
      elsif specificTests.nil?
        # not first attempt, but we haven't made it all the way through yet
        self.configureJavascriptReRunner(@testSuite.unStartedTests, @testSuite.finishedTests.length)
      else
        # we assume that we've already gone through and have been given specific tests to check out
        self.configureJavascriptReRunner(specificTests, 0)
      end

      # Setup new saltinel listener (will overwrite the old one if it exists)
      agentListener = SaltinelAgent.new(@javascriptRunner.saltinel)
      agentListener.eventSink = self
      @instrumentsRunner.addListener("saltinelAgent", agentListener)

      @instrumentsRunner.runOnce @javascriptRunner.saltinel
      if @appCrashed
        self.handleAppCrash
      end

    end while not (@testSuite.nil? or @testSuite.unStartedTests.empty? or @instrumentsStopped)

  end


  # print a summary of the tests that ran, in the form ..........!.!!.!...!..@...@.!
  #  where periods are passing tests, exclamations are fails, and '@' symbols are crashes
  def summarizeTestResults testSuite
    if testSuite.nil?
      puts "No test cases were received from the Javascript environment; check logs for possible setup problems.".red
      return
    end

    allTests      = testSuite.allTests
    unPassedTests = testSuite.unPassedTests

    if 0 == allTests.length
      puts "No tests ran".yellow
    elsif 0 < unPassedTests.length
      result = "Result: "
      allTests.each do |t|
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
      puts "#{unPassedTests.length} of #{allTests.length} tests FAILED".red   # failed in the test suite sense
    else
      puts "All #{allTests.length} tests PASSED".green
    end

  end

  def saveFailedTestsConfig(options, failedTests)
    return unless 0 < failedTests.length

    # save options to re-run failed tests
    newOptions = options.dup
    newOptions.illuminator.test.randomSeed = nil
    newOptions.illuminator.entryPoint      = "runTestsByName"
    newOptions.illuminator.test.names      = failedTests.map { |t| t.name }

    HostUtils.saveJSON(newOptions.to_h, BuildArtifacts.instance.illuminatorRerunFailedTestsSettings)
  end

  def removeAnyAppCrashes()
    Dir.glob("#{XcodeUtils.instance.getCrashDirectory}/#{@appName}*.crash").each do |crashPath|
      FileUtils.rmtree crashPath
    end
  end


  def handleAppCrash
    # tell the current test suite about any failures
    if @currentTest.nil?
      puts "ILLUMINATOR FAILURE TO HANDLE APP CRASH"
      return
    end

    # assume a crash report exists, and look for it
    crashes = self.reportAnyAppCrashes

    # write something useful depending on what crash reports are found
    case crashes.keys.length
    when 0
      stacktraceText = "No crash reports found in #{XcodeUtils.instance.getCrashDirectory}, perhaps the app exited cleanly instead"
    when 1
      stacktraceText = crashes[crashes.keys[0]]
    else
      stacktraceBody = crashes[crashes.keys[0]]
      stacktraceText = "Found multiple crashes: #{crashes.keys}  Here is the first one:\n\n #{stacktraceBody}"
    end

    @testSuite[@currentTest].stacktrace = stacktraceText
    @currentTest = nil
    self.saveJunitTestReport
  end



  def reportAnyAppCrashes()
    crashReportsPath = BuildArtifacts.instance.crashReports
    FileUtils.mkdir_p crashReportsPath unless File.directory?(crashReportsPath)

    crashes = Hash.new
    # TODO: glob if @appName is nil
    Dir.glob("#{XcodeUtils.instance.getCrashDirectory}/#{@appName}*.crash").each do |crashPath|
      # TODO: extract process name and ignore ["launchd_sim", ...]

      puts "Found a crash report from this test run at #{crashPath}"
      crashName = File.basename(crashPath, ".crash")
      crashReportPath = "#{crashReportsPath}/#{crashName}.crash"
      crashText = []
      if XcodeUtils.instance.createSymbolicatedCrashReport(@appLocation, crashPath, crashReportPath)
        puts "Created a symbolicated version of the crash report at #{crashReportPath}".red
      else
        FileUtils.cp(crashPath, crashReportPath)
        puts "Copied the crash report (assumed already symbolicated) to #{crashReportPath}".red
      end

      # get the first few lines for the log
      # TODO: possibly do error handling here just in case the file doesn't exist
      file = File.open(crashReportPath, 'rb')
      file.each do |line|
        break if line.match(/^Binary Images/)
        crashText << line
      end
      file.close

      crashText << "\n"
      crashText << "Full crash report saved at #{crashReportPath}"

      crashes[crashName] = crashText.join("")
    end
    crashes
  end


  def generateCoverage(gcWorkspace)
    destinationFile      = BuildArtifacts.instance.coverageReportFile
    xcodeArtifactsFolder = BuildArtifacts.instance.xcode
    destinationPath      = BuildArtifacts.instance.objectFiles

    excludeRegex = '.*(Debug|contrib).*'
    puts "Generating automation test coverage to #{destinationFile}".green
    sleep (3) # TODO: we are waiting for the app process to complete, maybe do this a different way

    # cleanup
    FileUtils.rm destinationFile, :force => true

    # we copy all the relevant build artifacts for coverage into a second folder.  we may not need to do this.
    filePaths = []
    Find.find(xcodeArtifactsFolder) do |pathP|
      path = pathP.to_s
      if /.*\.gcda$/.match path
        filePaths << path
        pathWithoutExt = path.chomp(File.extname(path))

        filePaths << pathWithoutExt + '.d'
        filePaths << pathWithoutExt + '.dia'
        filePaths << pathWithoutExt + '.o'
        filePaths << pathWithoutExt + '.gcno'
      end
    end

    filePaths.each do |path|
      FileUtils.cp path, destinationPath
    end

    command = "gcovr -r '#{gcWorkspace}' --exclude='#{excludeRegex}' --xml '#{destinationPath}' > '#{destinationFile}'"
    self.runAnnotatedCommand(command)

  end
end
