
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'DeviceInstaller.rb')


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


end
