require 'rubygems'
require 'fileutils'
require 'find'
require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationConfig.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ParameterStorage.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

####################################################################################################
# runner
####################################################################################################

class AutomationRunner

  def initialize(appName)
    @xcodePath        = XcodeUtils.instance.getXcodePath
    @crashPath        = "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    @xBuilder         = XcodeBuilder.new

    appOutputDirectory = BuildArtifacts.instance.xcode

    # if app name is not defined, assume that only one app exists and use that
    if appName.nil?
      @appLocation = Dir["#{appOutputDirectory}/*.app"][0]
    else
      @appLocation = "#{appOutputDirectory}/#{appName}.app"
    end
    @appName = appName
    self.cleanup
  end

  def setupForSimulator(simDevice, simVersion, simLanguage, skipSetSim)
    @simDevice = XcodeUtils.instance.getSimulatorID(simDevice, simVersion)
    @simLanguage = simLanguage

    unless skipSetSim
      command = "osascript '#{File.dirname(__FILE__)}/../reset_simulator.applescript'"
      self.runAnnotatedCommand(command)
    end
  end

  def setHardwareID(hardwareID)
    @hardwareID = hardwareID
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

  end


  def installOnDevice
    currentDir = Dir.pwd
    Dir.chdir "#{File.dirname(__FILE__)}/../../contrib/ios-deploy"
    command = "./ios-deploy -b '#{@appLocation}' -i #{@hardwareID} -r -n"
    self.runAnnotatedCommand(command)
    Dir.chdir currentDir
  end


  def runAllTests (report, doKillAfter, verbose = FALSE, startupTimeout = 30)

    unless @hardwareID.nil?
      self.installOnDevice
    end

    instruments = InstrumentsRunner.new

    instruments.appLocation     = @appLocation
    instruments.hardwareID      = @hardwareID
    instruments.simDevice       = @simDevice
    instruments.simLanguage     = @simLanguage

    #instruments.startupTimeout = startupTimeout
    #instruments.report = report
    #instruments.verbose = verbose

    instruments.start

    self.reportCrash
    if doKillAfter
      @xBuilder.killSim
    end

  end


  def runAnnotatedCommand(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
      io.each {||}
    end
  end


  def self.runWithOptions(options, workspace)
    options['workspace'] = Dir.pwd
    Dir.chdir(File.dirname(__FILE__) + '/../')

    ####################################################################################################
    # Sanity checks
    ####################################################################################################

    raise ArgumentError, 'Path to all tests was not supplied' if options['testPath'].nil?

    ####################################################################################################
    # Storing parameters
    ####################################################################################################


    tagsAny_arr = Array.new(0)

    tagsAny_arr = options['tagsAny'].split(',') unless options['tagsAny'].nil?

    tagsAll_arr = Array.new(0)
    tagsAll_arr = options['tagsAll'].split(',') unless options['tagsAll'].nil?

    tagsNone_arr = Array.new(0)
    tagsNone_arr = options['tagsNone'].split(',') unless options['tagsNone'].nil?

    pathToAllTests = options['testPath']
    unless pathToAllTests.start_with? workspace
      pathToAllTests = workspace + '/' + pathToAllTests
    end

    config = AutomationConfig.new(options['implementation'], pathToAllTests)

    unless options['hardwareID'].nil?
      config.setHardwareID options['hardwareID']
    end

    unless options['simDevice'].nil?
      config.setSimDevice options['simDevice']
    end

    unless options['simVersion'].nil?
      config.setSimVersion options['simVersion']
    end

    unless options['plistSettingsPath'].nil?
      config.setCustomConfig options['plistSettingsPath']
    end

    unless options['randomSeed'].nil?
      config.setRandomSeed options['randomSeed']
    end
    config.defineTags tagsAny_arr, tagsAll_arr, tagsNone_arr


    ####################################################################################################
    # Script action
    ####################################################################################################

    builder = AutomationBuilder.new()


    unless options['skipBuild']

      # if app name is not specified, make sure that we will only have one to run
      unless options['appName']
        builder.removeExistingApps()
      end
      builder.buildScheme(options['scheme'], options['sdk'], options['hardwareID'], workspace, options['coverage'], options['skipClean'])
    end

    runner = AutomationRunner.new(options['appName']) # can be nil

    if !options['hardwareID'].nil?
      runner.setHardwareID options['hardwareID']
    elsif
      runner.setupForSimulator options['simDevice'], options['simVersion'], options['simLanguage'], options['skipSetSim']
    end

    skipKillAfter = options['skipKillAfter']
    if options['coverage']
      skipKillAfter = TRUE
    end

    config.save() # must save AFTER automationRunner initializes
    runner.runAllTests(options['report'], !skipKillAfter, options['verbose'], options['timeout'])

    if options['coverage']
      runner.generateCoverage options
    end
  end


  def reportCrash()
    crashReportsPath = BuildArtifacts.instance.crashReports
    FileUtils.mkdir_p crashReportsPath unless File.directory?(crashReportsPath)

    outputFilename = 'crashReport.txt'
    Dir.glob("#{@crashPath}/#{@appName}*.crash").each do |crashPath|
      crashReportPath = "#{crashReportsPath}/#{outputFilename}"
      XcodeUtils.instance.createCrashReport(@appLocation, crashPath, crashReportPath)
      file = File.open(crashReportPath, 'rb')
      puts file.read.red
    end
  end


  def generateCoverage(options)
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

    command = "gcovr -r '" + options['workspace'] + "' --exclude='#{excludeRegex}' --xml '#{destinationPath}' > '#{destinationFile}'"
    self.runAnnotatedCommand(command)

  end
end
