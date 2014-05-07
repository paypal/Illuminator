require 'rubygems'
require 'fileutils'
require 'find'

require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationConfig.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ParameterStorage.rb')

####################################################################################################
# runner
####################################################################################################

class AutomationRunner

  def initialize path, scheme, appName
    @xcodePath = path

    @outputDirectory = "#{File.dirname(__FILE__)}/../../buildArtifacts/xcodeArtifacts";
    puts @outputDirectory
    @reportPath = "#{File.dirname(__FILE__)}/../../buildArtifacts/UIAutomationReport"
    @crashPath = "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    @crashReportsPath = "#{File.dirname(__FILE__)}/../../buildArtifacts/CrashReports"
    @xBuilder = XcodeBuilder.new

    @appName = appName + ".app"
    self.cleanup
  end

  def setupForSimulator simDevice, simLanguage, skipSetSim
    @simLanguage = simLanguage
    @simDevice = simDevice
    unless skipSetSim
      command = "osascript '#{File.dirname(__FILE__)}/../reset_simulator.applescript'"
      self.runAnnotatedCommand(command)
    end
  end

  def setHardwareID hardwareID
    @hardwareID = hardwareID
  end


  def cleanup
    FileUtils.rmtree @crashPath
    FileUtils.rmtree @reportPath
    FileUtils.rmtree @crashReportsPath
    FileUtils.mkdir_p @reportPath
  end


  def runAllTests (report, doKillAfter, verbose = FALSE, startupTimeout = 30)
    testCase = "#{File.dirname(__FILE__)}/../../buildArtifacts/testAutomatically.js"
    command = "DEVELOPER_DIR='#{@xcodePath}/Contents/Developer' "
    command << "'#{File.dirname(__FILE__)}/../../contrib/tuneup_js/test_runner/run' '#{@outputDirectory}/#{@appName}' '#{testCase}' '#{@reportPath}'"
    unless @hardwareID.nil?
      command << " -d #{hardwareID}"
    else
      command << " -w '#{@simDevice}'"
    end
    unless @simLanguage.nil?
      command << " -l '#{@simLanguage}'"
    end
    command << " --attempts=30"
    command << " --startuptimeout=#{startupTimeout}"
    if report
      command << " --xunit"
    end
    if verbose
      command << " -v"
    else
      command << " -v -b"
    end
    command << " 1>&2"
    self.runAnnotatedCommand(command)
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




   def self.runWithOptions options, workspace
      options["workspace"] = Dir.pwd
      Dir.chdir(File.dirname(__FILE__) + "/../")

      ####################################################################################################
      # Storing parameters
      ####################################################################################################


      tagsAny_arr = Array.new(0)

      tagsAny_arr = options["tagsAny"].split(',') unless options["tagsAny"].nil?

      tagsAll_arr = Array.new(0)
      tagsAll_arr = options["tagsAll"].split(',') unless options["tagsAll"].nil?

      tagsNone_arr = Array.new(0)
      tagsNone_arr = options["tagsNone"].split(',') unless options["tagsNone"].nil?

      pathToAllTests = options["testPath"]
      unless pathToAllTests.start_with? workspace
        pathToAllTests = workspace + '/' + pathToAllTests
      end

      config = AutomationConfig.new(options["implementation"], pathToAllTests)

      unless options["hardwareID"].nil?
        config.setHardwareID options["hardwareID"]
      end
     
      unless options["simDevice"].nil?
        config.setSimDevice options["simDevice"]
      end
     
      unless options["simVersion"].nil?
        config.setSimVersion options["simVersion"]
      end    
     
      unless options["plistSettingsPath"].nil?
        config.setCustomConfig options["plistSettingsPath"]
      end

      unless options["randomSeed"].nil?
        config.setRandomSeed options["randomSeed"]
      end
      config.defineTags tagsAny_arr, tagsAll_arr, tagsNone_arr



      ####################################################################################################
      # Script action
      ####################################################################################################


      unless options["skipBuild"]
        builder = AutomationBuilder.new()
        builder.buildScheme(options["scheme"], options["hardwareID"], workspace, options["coverage"])

      end

      runner = AutomationRunner.new(options["defaultXcode"],
                                    options["scheme"],
                                    options["appName"])

      if !options["hardwareID"].nil?
        runner.setHardwareID options["hardwareID"]
      elsif
        runner.setupForSimulator "#{options["simDevice"]} - Simulator - #{options["simVersion"]}", options["simLanguage"], options["skipSetSim"]
      end

      skipKillAfter = options["skipKillAfter"]
      if options["coverage"]
        skipKillAfter = TRUE
      end

      config.save() # must save AFTER automationRunner initializes
      runner.runAllTests(options["report"], !skipKillAfter, options["verbose"], options["timeout"])

      if options["coverage"]
        runner.generateCoverage options
      end
  end



  def reportCrash()
    unless File.directory?(@crashReportsPath)
      FileUtils.mkdir_p @crashReportsPath
    end

    # find symbolicatecrash file, which is different depending on the Xcode version.  We assume either/or
    frameworksPath = "#{@xcodePath}/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/PrivateFrameworks"
    symbolicatorPath = "#{frameworksPath}/DTDeviceKitBase.framework/Versions/A/Resources/symbolicatecrash"
    if not File.exist?(symbolicatorPath)
      symbolicatorPath = "#{frameworksPath}/DTDeviceKit.framework/Versions/A/Resources/symbolicatecrash"
    end

    Dir.glob("#{@crashPath}/*.crash").each do |path|
      outputFilename = "crashReport.txt"
      command =   "DEVELOPER_DIR='#{@xcodePath}/Contents/Developer' "
      command <<  "'#{symbolicatorPath}' "
      command <<  "-o '#{@crashReportsPath}/#{outputFilename}' '#{path}' '#{@outputDirectory}/#{@appName}.dSYM' 2>&1"
      self.runAnnotatedCommand(command)
      file = File.open("#{@crashReportsPath}/#{outputFilename}", "rb")
      puts file.read.red
    end
  end

  def generateCoverage(options)
    destinationFile = "#{File.dirname(__FILE__)}/../../buildArtifacts/coverage.xml"
    excludeRegex = ".*(Debug|contrib).*"
    puts "Generating automation test coverage to #{destinationFile}".green
    sleep (3)

    xcodeArtifactsFolder = Pathname.new("#{File.dirname(__FILE__)}/../../buildArtifacts/xcodeArtifacts").realpath.to_s
    destinationPath = "#{File.dirname(__FILE__)}/../../buildArtifacts/objectFiles"

    #cleanup
    FileUtils.rm destinationFile, :force => true
    FileUtils.rm_rf destinationPath
    unless File.directory?(destinationPath)
      FileUtils.mkdir_p destinationPath
    end
    destinationPath = Pathname.new("#{File.dirname(__FILE__)}/../../buildArtifacts/objectFiles").realpath.to_s

    filePaths = []
    Find.find(xcodeArtifactsFolder) do |pathP|
      path = pathP.to_s
      if /.*\.gcda$/.match path
        filePaths << path
        pathWithoutExt = path.chomp(File.extname(path))

        filePaths << pathWithoutExt + ".d"
        filePaths << pathWithoutExt + ".dia"
        filePaths << pathWithoutExt + ".o"
        filePaths << pathWithoutExt + ".gcno"
      end
    end

    filePaths.each do |path|
      FileUtils.cp path, destinationPath
    end

    command = "gcovr -r '" + options["workspace"] + "' --exclude='#{excludeRegex}' --xml '#{destinationPath}' > '#{destinationFile}'"
    self.runAnnotatedCommand(command)

  end
end
