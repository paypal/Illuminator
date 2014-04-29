require 'rubygems'
require 'fileutils'

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
  
  def setupForSimulator simDevice, simVersion, simLanguage
    @simLanguage = simLanguage
    command = "'#{File.dirname(__FILE__)}/../choose_sim_device.scpt' '#{simDevice}' '#{simVersion}' '#{@xcodePath}/Contents/Developer'"
    self.runAnnotatedCommand(command)
    command = "osascript '#{File.dirname(__FILE__)}/../reset_simulator.applescript'"
    self.runAnnotatedCommand(command)
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
      command << " -b"
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
      else
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
      elsif !options["skipSetSim"]
        runner.setupForSimulator options["simDevice"], options["simVersion"], options["simLanguage"]
      end
  
      config.save() # must save AFTER automationRunner initializes
      runner.runAllTests(options["report"], !options["skipKillAfter"], options["verbose"], options["timeout"])
  
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
  
  def generateCoverage()
    destinationFile = "buildArtifacts/coverage.xml"
    puts "generating automation test coverage to #{destinationFile}".green
    sleep (3)
    parameterStorage = PLISTStorage.new
    plist = parameterStorage.readFromStorageAtPath('buildParameters.plist')
    path = plist['objectDirectory']
    
    iPhonePath = "#{path}/i386"
    corePath = "#{path}/../../../../PPHCore.build/Debug-iphonesimulator/PPHCore.build/Objects-normal/i386"
    destinationPath = "./objectFiles"

    
    FileUtils.rm destinationFile, :force => true
    FileUtils.rm_rf destinationPath 
    unless File.directory?(destinationPath)
      FileUtils.mkdir destinationPath 
    end
    
    FileUtils.cp_r "#{iPhonePath}/.", destinationPath 
    FileUtils.cp_r "#{corePath}/.", destinationPath 
    
    excludeRegex = ".*(Debug|contrib).*"
    
    command = "gcovr -r ./ --exclude='#{excludeRegex}' --xml '#{destinationPath}' > #{destinationFile}"
    self.runAnnotatedCommand(command)
    
  end
end
