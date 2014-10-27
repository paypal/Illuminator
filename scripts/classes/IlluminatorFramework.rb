
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationRunner.rb')


class IlluminatorFramework

  ################################################################################################
  # MAIN ENTRY POINT
  ################################################################################################
  def self.runWithOptions(options, workspace)

    # Initialization
    builder = AutomationBuilder.new
    runner = AutomationRunner.new

    # Run appropriate shell scripts for cleaning, building, and running real hardware
    unless options['skipBuild']
      # TODO: forceClean = FALSE
      builder.scheme = options['scheme']
      builder.workspace = workspace
      builder.doClean = (not options['skipClean'])

      # if app name is not specified, make sure that we will only have one to run
      XcodeUtils.removeExistingApps(BuildArtifacts.instance.xcode) unless options['appName']
      if not builder.buildForAutomation(options['sdk'], options['hardwareID'])
        puts 'Build failed, check logs for results'.red
        exit builder.exitCode
      end
    end

    self.installOnDevice unless options['hardwareID'].nil?

    runner.workspace = workspace
    runner.appName = options['appName']

    runner.runWithOptions(options)

    unless options['skipKillAfter']
      #TODO: call kill_all_sim_processes.sh
    end
  end


  # TODO: make a class that does this
  def self.installOnDevice
    currentDir = Dir.pwd
    Dir.chdir "#{File.dirname(__FILE__)}/../../contrib/ios-deploy"
    # TODO: detect ios-deploy
    self.runAnnotatedCommand("./ios-deploy -b '#{@appLocation}' -i #{@hardwareID} -r -n")
    Dir.chdir currentDir
  end



end
