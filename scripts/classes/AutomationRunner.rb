require 'rubygems'
require 'fileutils'
require 'find'
require 'pathname'
require 'json'

require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'JavascriptRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'TestSuite.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'TestDefinitions.rb')

require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/PrettyOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/FullOutput.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/ConsoleLogger.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/TestListener.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'listeners/SaltinelAgent.rb')

####################################################################################################
# runner
####################################################################################################


# responsibilities:
#  - convert combined settings hash into individual class settings
#  - prepare javascript config, and start instruments
#  - process any crashes
#  - run coverage
class AutomationRunner
  include SaltinelAgentEventSink
  include TestListenerEventSink

  attr_accessor :appName
  attr_accessor :workspace

  attr_reader :instrumentsRunner
  attr_reader :javascriptRunner

  def initialize
    @crashPath         = "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    @testDefs          = nil
    @testSuite         = nil
    @currentTest       = nil
    @stackTraceLines   = nil
    @stackTraceRecord  = false
    @javascriptRunner  = JavascriptRunner.new
    @instrumentsRunner = InstrumentsRunner.new

    @instrumentsRunner.addListener("consolelogger", ConsoleLogger.new)
  end


  def cleanup
    # start a list of what to remove
    dirsToRemove = [@crashPath]

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
    dirsToRemove.each do |dir|
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
    rawList = JSON.parse( IO.read(jsonPath) )

    # create a test suite, and add test cases to it.  look up class names from test defs
    @testSuite = TestSuite.new
    rawList["scenarioNames"].each do |n|
      test = @testDefs.byName(n)
      testFileName = test["inFile"]
      testFnName   = test["definedBy"]
      className    = testFileName.sub(".", "_") + "." + testFnName
      @testSuite.addTestCase(className, n)
    end
  end


  def saltinelAgentGotStacktraceHint
    @stackTraceRecord = true
  end


  def testListenerGotTestStart name
    @testSuite[@currentTest].error "ILLUMINATOR FAILURE TO LISTEN" unless @currentTest.nil?
    @testSuite[name].start!
    @currentTest = name
    @stackTraceRecord = false
    @stackTraceLines = Array.new
  end

  def testListenerGotTestPass name
    puts "ILLUMINATOR FAILURE TO SORT TESTS".red unless name == @currentTest
    @testSuite[name].pass!
    @currentTest = nil
  end

  def testListenerGotTestFail message
    if @testSuite.nil?
      puts "Failure before test suite was received: #{message}".red
      return
    elsif @currentTest.nil?
      puts "Failure outside of a test: #{message}".red
    elsif message == "The target application appears to have died"
      # do nothing; assume a crash report exists and leave it to the crash handler code to clean this up
    else
      @testSuite[@currentTest].fail message
      @testSuite[@currentTest].stacktrace = @stackTraceLines.join("\n")
      @currentTest = nil
    end
  end

  def testListenerGotLine(status, message)
    return if @testSuite.nil? or @currentTest.nil?
    line = message
    line = "#{status}: #{line}" unless status.nil?
    @testSuite[@currentTest] << line
    @stackTraceLines         << line if @stackTraceRecord
  end


  def runAnnotatedCommand(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
      io.each {||}
    end
  end

  def configureJavascriptRunner(options)
    jsConfig = @javascriptRunner

    jsConfig.implementation      = options.javascript.implementation
    jsConfig.testPath            = options.javascript.testPath
    jsConfig.customJSConfigPath  = options.javascript.customConfigPath

    jsConfig.entryPoint          = options.illuminator.entryPoint
    jsConfig.scenarioList        = options.illuminator.test.names
    jsConfig.tagsAny             = options.illuminator.test.tags.any
    jsConfig.tagsAll             = options.illuminator.test.tags.all
    jsConfig.tagsNone            = options.illuminator.test.tags.none
    jsConfig.randomSeed          = options.illuminator.test.randomSeed
    jsConfig.hardwareID          = options.illuminator.hardwareID

    jsConfig.simDevice           = options.simulator.device
    jsConfig.simVersion          = options.simulator.version

    jsConfig.writeConfiguration()
  end

  def configureJavascriptReRunner scenarioList
    jsConfig = @javascriptRunner

    jsConfig.randomSeed = nil
    jsConfig.entryPoint = "runTestsByName"
    jsConfig.scenarioList = scenarioList

    jsConfig.writeConfiguration()
  end


  def runWithOptions(options)
    gcovrWorkspace = Dir.pwd
    Dir.chdir(File.dirname(__FILE__) + '/../')

    # Sanity checks
    raise ArgumentError, 'Entry point was not supplied'       if options.illuminator.entryPoint.nil?
    raise ArgumentError, 'Path to all tests was not supplied' if options.javascript.testPath.nil?
    raise ArgumentError, 'Implementation was not supplied'    if options.javascript.implementation.nil?

    @appName = options.xcode.appName
    @appLocation = BuildArtifacts.instance.appLocation(@appName)


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

    # listener to provide screen output
    if options.instruments.doVerbose
      @instrumentsRunner.addListener("consoleoutput", FullOutput.new)
    else
      @instrumentsRunner.addListener("consoleoutput", PrettyOutput.new)
    end

    XcodeUtils.killAllSimulatorProcesses
    XcodeUtils.resetSimulator if options.illuminator.hardwareID.nil? and options.illuminator.task.setSim

    @testSuite = nil

    # loop until all test cases are covered.
    # we won't get the actual test list until partway through -- from a listener callback
    startTime = Time.now
    begin
      self.removeAnyAppCrashes

      # Setup javascript
      if @testSuite.nil?
        self.configureJavascriptRunner options
      else
        self.configureJavascriptReRunner(@testSuite.unStartedTests)
      end

      # Setup new saltinel listener
      agentListener = SaltinelAgent.new(@javascriptRunner.saltinel)
      agentListener.eventSink = self
      @instrumentsRunner.addListener("saltinelAgent", agentListener)

      @instrumentsRunner.runOnce @javascriptRunner.saltinel
      numCrashes = self.reportAnyAppCrashes
    end while not (@testSuite.nil? or @testSuite.unStartedTests.empty?)
    totalTime = Time.at(Time.now - startTime).gmtime.strftime("%H:%M:%S")
    puts "Automation completed in #{totalTime}".green


    # DONE LOOPING
    unless @testSuite.nil?
      f = File.open(BuildArtifacts.instance.junitReportFile, 'w')
      f.write(@testSuite.to_xml)
      f.close

      self.generateCoverage gcovrWorkspace if options.illuminator.task.coverage #TODO: only if there are no crashes?
      self.saveFailedTestsConfig(options, @testSuite.failedTests)
    end

    XcodeUtils.killAllSimulatorProcesses if options.simulator.killAfter

    if "describe" == options.illuminator.entryPoint
      return true       # no tests needed to run
    else
      self.summarizeTestResults @testSuite
    end

    return false if @testSuite.nil?                         # no tests were received
    return false if 0 == @testSuite.passedTests.length      # no tests passed, or none ran
    return false if 0 < @testSuite.failedTests.length       # 1 or more tests failed
    return true
  end

  # print a summary of the tests that ran, in the form ..........!.!!.!...!..@...@.!
  #  where periods are passing tests, exclamations are fails, and '@' symbols are crashes
  def summarizeTestResults testSuite
    if testSuite.nil?
      puts "No test cases were received from the Javascript environment; check logs for possible setup problems.".red
      return
    end

    allTests    = testSuite.allTests
    failedTests = testSuite.failedTests

    if 0 == allTests.length
      puts "No tests ran".yellow
    elsif 0 < failedTests.length
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
      puts "#{failedTests.length} of #{allTests.length} tests FAILED".red
    else
      puts "All #{allTests.length} tests PASSED".green
    end

  end

  def saveFailedTestsConfig(options, failedTests)
    return unless 0 < failedTests.length

    # save options to re-run failed tests
    newOptions = options.dup
    newOptions.illuminator.test.randomSeed = nil
    newOptions.illuminator.entryPoint = "runTestsByName"
    newOptions.illuminator.test.names = failedTests.map { |t| t.name }
    customOptions = nil

    unless newOptions.javascript.customConfigPath.nil?
      customOptions = JSON.parse( IO.read(newOptions.javascript.customConfigPath) )
      newOptions.javascript.customConfigPath = nil
    end

    f = File.open(BuildArtifacts.instance.illuminatorRerunFailedTestsSettings, 'w')
    f << JSON.pretty_generate({
                                "options" => newOptions.to_h,
                                "customConfig" => customOptions,
                              })
    f.close

  end

  def removeAnyAppCrashes()
    Dir.glob("#{@crashPath}/#{@appName}*.crash").each do |crashPath|
      FileUtils.rmtree crashPath
    end
  end


  def reportAnyAppCrashes()
    crashReportsPath = BuildArtifacts.instance.crashReports
    FileUtils.mkdir_p crashReportsPath unless File.directory?(crashReportsPath)

    crashes = 0
    # TODO: glob if @appName is nil
    Dir.glob("#{@crashPath}/#{@appName}*.crash").each do |crashPath|
      # TODO: extract process name and ignore ["launchd_sim", ...]

      puts "Found a crash report from this test run at #{crashPath}"
      crashName = File.basename(crashPath, ".crash")
      crashReportPath = "#{crashReportsPath}/#{crashName}.txt"
      crashText = []
      unless XcodeUtils.instance.createCrashReport(@appLocation, crashPath, crashReportPath)
        puts "Failed to save crash report.".red
      else
        # get the first few lines for the log
        file = File.open(crashReportPath, 'rb')
        file.each do |line|
          break if line.match(/^Binary Images/)
          crashText << line
        end
        file.close

        logLine = "Full crash report saved at #{crashReportPath}"
        puts logLine.red
        crashText << "\n"
        crashText << logLine
      end

      crashes += 1

      # tell the current test suite about any failures
      unless @currentTest.nil?
        @testSuite[@currentTest].error "The target application appears to have died."
        @testSuite[@currentTest].stacktrace = crashText.join("")
        @currentTest = nil
      end
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
