require 'rubygems'
require 'fileutils'
require 'find'
require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'JavascriptRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

####################################################################################################
# runner
####################################################################################################


# responsibilities:
#  - convert combined settings hash into individual class settings
#  - prepare javascript config, and start instruments
#  - process any crashes
#  - run coverage
class AutomationRunner
  attr_accessor :appName
  attr_accessor :workspace

  attr_reader :instrumentsRunner
  attr_reader :javascriptRunner

  def initialize
    @crashPath         = "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    @javascriptRunner  = JavascriptRunner.new
    @instrumentsRunner = InstrumentsRunner.new
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


  def runAnnotatedCommand(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
      io.each {||}
    end
  end


  def configureJavascriptRunner(options)
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
    unless pathToAllTests.start_with? @workspace
      pathToAllTests = File.join(@workspace, pathToAllTests)
    end

    jsConfig.writeConfiguration pathToAllTests
  end


  def runWithOptions(options)
    gcovrWorkspace = Dir.pwd
    Dir.chdir(File.dirname(__FILE__) + '/../')

    # Sanity checks
    raise ArgumentError, 'Path to all tests was not supplied' if options['testPath'].nil?
    raise ArgumentError, 'Implementation was not supplied' if options['implementation'].nil?

    @appName = options['appName']
    @appLocation = BuildArtifacts.instance.appLocation(options['appName'])

    # pre-run cleanup
    self.cleanup
    @instrumentsRunner.cleanup
    # TODO: @javascriptRunner cleanup?

    # Setup javascript
    self.configureJavascriptRunner(options)

    # set up instruments
    @instrumentsRunner.startupTimeout = options['timeout']
    @instrumentsRunner.hardwareID     = options['hardwareID']
    @instrumentsRunner.appLocation    = @appLocation
    @instrumentsRunner.simDevice      = XcodeUtils.instance.getSimulatorID(options['simDevice'], options['simVersion']) if options['hardwareID'].nil?
    @instrumentsRunner.simLanguage    = options['simLanguage'] if options['hardwareID'].nil?

    XcodeUtils.killAllSimulatorProcesses
    XcodeUtils.resetSimulator if options['hardwareID'].nil? unless options['skipSetSim']

    @instrumentsRunner.runOnce

    numCrashes = self.reportAnyAppCrashes
    self.generateCoverage gcovrWorkspace if options['coverage'] #TODO: only if there are no crashes?
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
      XcodeUtils.instance.createCrashReport(@appLocation, crashPath, crashReportPath)
      file = File.open(crashReportPath, 'rb')
      file.each do |line|
        break if line.match(/^Binary Images/)
        print line.red
      end
      file.close
      crashes += 1
      puts "Full crash report saved at #{crashReportPath}"
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
