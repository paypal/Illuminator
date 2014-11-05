require 'ostruct'

require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'DeviceInstaller.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')


class IlluminatorFramework

  def self.willClean options
    return true if options.illuminator.clean.derived
    return true if options.illuminator.clean.artifacts
    return true if options.illuminator.clean.xcode
    return false
  end

  def self.cleanCountdown
    countdown = "3....2....1...."
    print "Cleaning in ".yellow
    countdown.split("").each do |c|
      print c.yellow
      sleep(0.2)
    end
    print "\n"
  end

  ################################################################################################
  # MAIN ENTRY POINT
  ################################################################################################
  def self.runWithOptions(options, workspace)

    hardwareID = options.illuminator.hardwareID
    appName    = options.xcode.appName

    cleanDirs = {
      "~/Library/Developer/Xcode/DerivedData" => options.illuminator.clean.derived,
      BuildArtifacts.instance.xcode(true)     => options.illuminator.clean.artifacts,
      # can't delete build artifacts root, because important files might already be there
    }

    # do any initial cleaning
    self.cleanCountdown if self.willClean(options) and (not options.illuminator.clean.noDelay)
    cleanDirs.each do |dir, doClean|
      if doClean
        puts "Illuminator cleanup: removing #{dir}"
        FileUtils.rmtree dir
      end
    end

    # Initialize builder and build
    if options.illuminator.task.build
      builder = AutomationBuilder.new
      builder.workspace = workspace
      builder.scheme    = options.xcode.scheme
      builder.doClean   = options.illuminator.clean.xcode

      # if app name is not specified, make sure that we will only have one to run
      XcodeUtils.removeExistingApps(BuildArtifacts.instance.xcode) if appName.nil?
      if builder.buildForAutomation(options.xcode.sdk, hardwareID)
        puts 'Build succeded'.green
      else
        puts 'Build failed, check logs for results'.red
        exit builder.exitCode
      end
    end

    # Install on real device
    unless hardwareID.nil?
      appLocation = BuildArtifacts.instance.appLocation(appName)
      DeviceInstaller.instance.installOnDevice(appLocation, hardwareID)
    end

    # Initialize automation
    runner = AutomationRunner.new
    runner.workspace = workspace
    runner.appName   = appName
    runner.cleanup
    return runner.runWithOptions(options)

  end

  # overrideOptions is a lambda function that acts on the settings object
  # overrideCustomOptions is a lambda function that acts on the custom settings object
  def self.reRun(configPath, workspace, overrideOptions = nil, overrideCustomOptions = nil)

    # load config from supplied path
    savedConfig = JSON.parse( IO.read(configPath) )

    # process any overrides
    options = overrideOptions.(IlluminatorSettings.new(savedConfig["options"])) unless overrideOptions.nil?

    # write a new custom config file from the input settings
    unless savedConfig["customConfig"].nil?
      customConfig = overrideCustomOptions.(savedConfig["customConfig"])
      puts "customConfig is #{customConfig.class.to_s} :: #{customConfig.to_s}"

      f = File.open(BuildArtifacts.instance.illuminatorCustomConfigFile, 'w')
      f << JSON.pretty_generate(customConfig)
      f.close
      options.javascript.customConfigPath = BuildArtifacts.instance.illuminatorCustomConfigFile
    end

    return self.runWithOptions options, workspace
  end

end
