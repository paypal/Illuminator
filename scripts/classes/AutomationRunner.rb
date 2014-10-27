require 'rubygems'
require 'fileutils'
require 'find'
require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'JavascriptRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

####################################################################################################
# runner
####################################################################################################

class AutomationRunner

  attr_reader :hardwareID

  attr_reader :automationBuilder
  attr_reader :instrumentsRunner
  attr_reader :javascriptRunner

  def initialize(appName)
    @crashPath        = "#{ENV['HOME']}/Library/Logs/DiagnosticReports"

    appOutputDirectory = BuildArtifacts.instance.xcode

    # if app name is not defined, assume that only one app exists and use that
    if appName.nil?
      @appLocation = Dir["#{appOutputDirectory}/*.app"][0]
    else
      @appLocation = "#{appOutputDirectory}/#{appName}.app"
    end
    @appName = appName

    @javascriptRunner = JavascriptRunner.new
    @automationBuilder = AutomationBuilder.new
    @instrumentsRunner = InstrumentsRunner.new

    @instrumentsRunner.appLocation  = @appLocation
    @instrumentsRunner.hardwareID   = @hardwareID
  end


  def setupForSimulator(simDevice, simVersion, simLanguage, skipSetSim)
    @instrumentsRunner.simDevice = XcodeUtils.instance.getSimulatorID(simDevice, simVersion)
    @instrumentsRunner.simLanguage = simLanguage

    unless skipSetSim
      command = "osascript '#{File.dirname(__FILE__)}/../reset_simulator.applescript'"
      self.runAnnotatedCommand(command)
    end
  end


  def cleanup
    # start a list of what to remove
    dirsToRemove = [@crashPath]

    # FIXME: this should probably get moved to instrument runner
    # keys to the methods of the BuildArtifacts singleton that we want to remove
    buildArtifactKeys = [:crashReports, :instruments, :objectFiles, :coverageReportFile]
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

    @instrumentsRunner.cleanup
    # TODO: @javascriptRunner cleanup?
    # TODO: @automationBuilder cleanup?
  end


  def installOnDevice
    currentDir = Dir.pwd
    Dir.chdir "#{File.dirname(__FILE__)}/../../contrib/ios-deploy"
    # TODO: detect ios-deploy
    self.runAnnotatedCommand("./ios-deploy -b '#{@appLocation}' -i #{@hardwareID} -r -n")
    Dir.chdir currentDir
  end


  def runAnnotatedCommand(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
      io.each {||}
    end
  end


  def configureJavascriptRunner(options, workspace)
    jsConfig = @javascriptRunner

    jsConfig.implementation = options['implementation']

    jsConfig.entryPoint          = "runTestsByTag"
    jsConfig.tagsAny             = options['tagsAny'].split(',') unless options['tagsAny'].nil?
    jsConfig.tagsAll             = options['tagsAll'].split(',') unless options['tagsAll'].nil?
    jsConfig.tagsNone            = options['tagsNone'].split(',') unless options['tagsNone'].nil?

    jsConfig.hardwareID          = options['hardwareID'] unless options['hardwareID'].nil?
    jsConfig.simDevice           = options['simDevice'] unless options['simDevice'].nil?
    jsConfig.simVersion          = options['simVersion'] unless options['simVersion'].nil?
    jsConfig.customJSConfigPath  = options['customJSConfigPath'] unless options['customJSConfigPath'].nil?
    jsConfig.randomSeed          = options['randomSeed'] unless options['randomSeed'].nil?

    pathToAllTests = options['testPath']
    unless pathToAllTests.start_with? workspace
      pathToAllTests = File.join(workspace, pathToAllTests)
    end

    jsConfig.writeConfiguration pathToAllTests
  end


  ################################################################################################
  # MAIN ENTRY POINT
  ################################################################################################
  def self.runWithOptions(options, workspace)
    gcovrWorkspace = Dir.pwd
    Dir.chdir(File.dirname(__FILE__) + '/../')

    # Sanity checks
    raise ArgumentError, 'Path to all tests was not supplied' if options['testPath'].nil?
    raise ArgumentError, 'Implementation was not supplied' if options['implementation'].nil?

    # Initialization
    runner = AutomationRunner.new(options['appName']) # can be nil
    builder = runner.automationBuilder
    instruments = runner.instrumentsRunner
    jsConfig = runner.javascriptRunner

    # pre-run cleanup
    runner.cleanup

    # Setup javascript
    runner.configureJavascriptRunner(options, workspace)

    # set up instruments
    instruments.startupTimeout = options['timeout']
    # instruments.report = options['report'] # currently removed
    # instruments.verbose = options['verbose'] # not added yet

    # Run appropriate shell scripts for cleaning, building, and running real hardware
    unless options['skipBuild']
      # TODO: forceClean = FALSE
      builder.scheme = options['scheme']
      builder.workspace = workspace
      builder.doClean = (not options['skipClean'])

      # if app name is not specified, make sure that we will only have one to run
      XcodeUtils.instance.removeExistingApps(BuildArtifacts.instance.xcode) unless options['appName']
      if not builder.buildForAutomation(options['sdk'], options['hardwareID'])
        puts 'Build failed, check logs for results'.red
        exit builder.exitCode
      end
    end

    if options['hardwareID'].nil?
      runner.setupForSimulator options['simDevice'], options['simVersion'], options['simLanguage'], options['skipSetSim']
    else
      runner.hardwareID = options['hardwareID']
      self.installOnDevice
    end

    instruments.runOnce

    numCrashes = runner.reportAnyAppCrashes
    runner.generateCoverage gcovrWorkspace if options['coverage'] #TODO: only if there are no crashes?

    unless options['skipKillAfter']
      #TODO: call kill_all_sim_processes.sh
    end
  end


  def reportAnyAppCrashes()
    crashReportsPath = BuildArtifacts.instance.crashReports
    FileUtils.mkdir_p crashReportsPath unless File.directory?(crashReportsPath)

    crashes = 0
    outputFilename = 'crashReport.txt'
    Dir.glob("#{@crashPath}/#{@appName}*.crash").each do |crashPath|
      crashReportPath = "#{crashReportsPath}/#{outputFilename}"
      XcodeUtils.instance.createCrashReport(@appLocation, crashPath, crashReportPath)
      file = File.open(crashReportPath, 'rb')
      puts file.read.red
      crashes += 1
    end
    crashes
  end


  def generateCoverage(workspace)
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

    command = "gcovr -r '#{workspace}' --exclude='#{excludeRegex}' --xml '#{destinationPath}' > '#{destinationFile}'"
    self.runAnnotatedCommand(command)

  end
end
