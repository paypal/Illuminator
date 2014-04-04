require 'rubygems'
require 'fileutils'

require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ParameterStorage.rb')

####################################################################################################
# Builder
####################################################################################################

class AutomationBuilder

  def initialize

    resultPath = File.dirname(__FILE__) + "/../../buildArtifacts/xcodeArtifacts"
    @builder = XcodeBuilder.new
    @builder.addParameter('configuration','Debug')
    @builder.addEnvironmentVariable('CONFIGURATION_BUILD_DIR',resultPath)
    #TODO: add config

    @builder.clean
    @builder.killSim
  end

  def runScheme (scheme, hardwareID = nil, workspace)
    unless workspace.nil?
      Dir.chdir(workspace)
    end
    
    if hardwareID.nil?
      @builder.addParameter('sdk','iphonesimulator7.0')
      @builder.addParameter('arch','i386')
    else 
      @builder.addParameter('arch','armv7')
      @builder.addEnvironmentVariable("AUTOMATION_UDID",hardwareID)
    end
    
    @builder.addParameter('scheme',scheme)
    @builder.run

  end


end

####################################################################################################
# runner
####################################################################################################

class AutomationRunner

  def initialize(path, scheme, appName, doBuild, doCoverage, doSetSimulator, simDevice, simVersion, simLanguage, startupTimeout = 30, hardwareID = nil, workspace = nil)
    @xcodePath = path
    if doBuild
      directory = Dir.pwd
      self.build(scheme, hardwareID, workspace)
      Dir.chdir(directory)
    end
    @doCoverage = doCoverage
    
    parameterStorage = PLISTStorage.new
    plist = parameterStorage.readFromStorageAtPath('buildParameters.plist')
    
    if hardwareID.nil?
      @doSetSimulator = doSetSimulator
      @simDevice = simDevice
      @simVersion = simVersion
      @simLanguage = simLanguage
    else 
      @doSetSimulator = FALSE
      @simDevice = nil
      @simVersion = nil
      @simLanguage = nil
    end
    
    @outputDirectory = File.dirname(__FILE__) + "/../../buildArtifacts/xcodeArtifacts";
    
    @startupTimeout = startupTimeout
    @reportPath = "buildArtifacts/UIAutomationReport"
    @crashPath = "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    @crashReportsPath = "CrashReports"
    @xBuilder = XcodeBuilder.new
   
    puts @outputDirectory
    @appName = appName + ".app"
    self.cleanup
  end

  def build(scheme, hardwareID, workspace)
    builder = AutomationBuilder.new
    builder.runScheme(scheme, hardwareID, workspace)
  end

  def cleanup
    puts @crashPath
    FileUtils.rmtree @crashPath
    FileUtils.rmtree @reportPath
    FileUtils.rmtree @crashReportsPath
    FileUtils.mkdir_p @reportPath
    
  end


  def runAllTests (report, doKillAfter, pretty = FALSE, hardwareID = nil)
    testFolder = "#{File.dirname(__FILE__)}/../../"
    self.runTestCase("#{testFolder}testAutomatically.js", report, doKillAfter, pretty, hardwareID)
    if @doCoverage
      self.generateCoverage
    end
  end

  def setSimulator()
    command = "#{File.dirname(__FILE__)}/../choose_sim_device.scpt '#{@simDevice}' '#{@simVersion}' '#{@xcodePath}/Contents/Developer'"
    self.runAnnotatedCommand(command)
    command = "osascript #{File.dirname(__FILE__)}/../reset_simulator.applescript"
    self.runAnnotatedCommand(command)
  end

  def runAnnotatedCommand(command)
    puts "\n"
    puts command.green
    IO.popen command do |io|
        io.each {||}
    end
  end


  def runTestCase(testCase, report, doKillAfter, pretty = FALSE, hardwareID = nil)
    if @doSetSimulator
      setSimulator()
    end

    command = "DEVELOPER_DIR='#{@xcodePath}/Contents/Developer' "
    command << File.dirname(__FILE__) + "/../../contrib/tuneup_js/test_runner/run '#{@outputDirectory}/#{@appName}' '#{testCase}' '#{@reportPath}'"
    unless hardwareID.nil?
      command << " -d #{hardwareID}"
    end
    unless @simLanguage.nil?
      command << " -l '#{@simLanguage}'"
    end
    if pretty
      command << " -b"
    end
    command << " --attempts=30"
    command << " --startuptimeout=#{@startupTimeout}"
    if report
      command << " --xunit -v"
    end
    command << " 1>&2"
    self.runAnnotatedCommand(command)
    self.reportCrash
    if doKillAfter
      @xBuilder.killSim
    end
  
  end
  
  def reportCrash()
    unless File.directory?(@crashReportsPath)
      FileUtils.mkdir @crashReportsPath 
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
    destinationFile = "coverage.xml"
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
