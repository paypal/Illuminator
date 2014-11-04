
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'DeviceInstaller.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/classes/BuildArtifacts.rb')


class IlluminatorFramework

  ################################################################################################
  # MAIN ENTRY POINT
  ################################################################################################
  def self.runWithOptions(options, workspace)

    hardwareID = options['hardwareID']
    appName    = options['appName']

    # Initialize builder and build
    unless options['skipBuild']
      builder = AutomationBuilder.new
      builder.workspace = workspace
      builder.scheme    = options['scheme']
      builder.doClean   = (not options['skipClean'])  # TODO: skip clean by default with array of things to clean

      # if app name is not specified, make sure that we will only have one to run
      XcodeUtils.removeExistingApps(BuildArtifacts.instance.xcode) if appName.nil?
      if builder.buildForAutomation(options['sdk'], hardwareID)
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


  def self.reRun(configPath, workspace, overrideOptions = nil, overrideCustomOptions = nil)

    overrideOptions       = {} if overrideOptions.nil?
    overrideCustomOptions = {} if overrideCustomOptions.nil?

    # load config from supplied path
    savedConfig = JSON.parse( IO.read(configPath) )

    # process any overrides
    overrideOptions.each { |key, value| savedConfig[key] = value }

    # write a new custom config file from the input settings
    unless savedConfig["customConfig"].nil?
      customConfig = savedConfig["customConfig"]
      overrideCustomOptions.each { |key, value| customConfig[key] = value }
      f = File.open(BuildArtifacts.instance.illuminatorCustomConfigFile, 'w')
      f << JSON.pretty_generate(customConfig)
      f.close
      savedConfig["options"]["customJSConfigPath"] = BuildArtifacts.instance.illuminatorCustomConfigFile
    end

    return self.runWithOptions savedConfig["options"], workspace
  end

end
