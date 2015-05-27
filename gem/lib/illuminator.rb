require "illuminator/version"

require "illuminator/automation-builder"
require "illuminator/automation-runner"
require "illuminator/argument-parsing"
require "illuminator/device-installer"
require "illuminator/build-artifacts"
require "illuminator/host-utils"
require "illuminator/xcode-utils"
require "illuminator/options"


module Illuminator

  class Framework

    def self.will_clean options
      return true if options.illuminator.clean.derived
      return true if options.illuminator.clean.artifacts
      return true if options.illuminator.clean.xcode
      return false
    end

    def self.clean_countdown
      countdown = "3....2....1...."
      print "Cleaning in ".yellow
      countdown.split("").each do |c|
        print c.yellow
        sleep(0.2)
      end
      print "\n"
    end

    def self.validate_options(options)
      noproblems = true

      # so we can call BS on the user
      bs = lambda do |message|
        puts message.red
        noproblems = false
      end

      # some things to check
      things = {
        "Build artifacts directory" => options.build_artifacts_dir,
      }

      # now check them
      things.each { |k, v| bs.call "#{k} was not specified" if v.nil? }

      # fail quickly if simulator device and/or version are wrong
      if options.illuminator.hardware_id.nil?
        device = options.simulator.device
        version = options.simulator.version
        devices = XcodeUtils.instance.get_simulator_device_types()
        versions = XcodeUtils.instance.get_simulator_runtimes()


        unless devices.include? device
          bs.call "Specified simulator device '#{device}' does not appear to be installed -  options are #{devices}"
        end

        unless versions.include? version
          bs.call "Specified simulator iOS version '#{version}' does not appear to be installed -  options are #{versions}"
        end

      end

      # check paths
      if options.illuminator.task.automate
        bs.call "Implementation was not specified" if options.javascript.implementation.nil?

        if options.javascript.test_path.nil?
          bs.call "Javascript test definitions file was not specified"
        else
          unless File.exists? options.javascript.test_path
            bs.call "Could not find specified javascript test definitions file at '#{options.javascript.test_path}'"
          end
        end
      end

      return noproblems
    end

  end



  def self.run_with_options(originalOptions)

    options = Options.new(originalOptions.to_h) # immediately create a copy of the options, because we may mangle them
    Illuminator::BuildArtifacts.instance.set_root options.build_artifacts_dir

    hardware_id = options.illuminator.hardware_id
    app_name    = options.xcode.app_name

    # validate some inputs
    return false unless Framework.validate_options(options)

    # do any initial cleaning
    clean_dirs = {
      HostUtils.realpath("~/Library/Developer/Xcode/DerivedData") => options.illuminator.clean.derived,
      Illuminator::BuildArtifacts.instance.root(true)             => options.illuminator.clean.artifacts,
    }
    Framework.clean_countdown if Framework.will_clean(options) and (not options.illuminator.clean.no_delay)
    clean_dirs.each do |d, do_clean|
      dir = HostUtils.realpath d
      if do_clean
        puts "Illuminator cleanup: removing #{dir}"
        FileUtils.rmtree dir
      end
    end

    # Initialize builder and build
    if (not options.instruments.app_location.nil?)
      puts "Skipping build because app_location was provided".yellow if options.illuminator.task.build
      options.instruments.app_location = HostUtils::realpath(options.instruments.app_location)
    elsif (not options.illuminator.task.build)
      options.instruments.app_location = Illuminator::BuildArtifacts.instance.app_location(app_name) # assume app is here
    else
      builder = AutomationBuilder.new
      builder.project_dir = options.xcode.project_dir
      builder.project    = options.xcode.project
      builder.scheme     = options.xcode.scheme
      builder.workspace  = options.xcode.workspace
      builder.do_clean    = options.illuminator.clean.xcode
      unless options.xcode.environment_vars.nil?
        options.xcode.environment_vars.each { |name, value| builder.add_environment_variable(name, value) }
      end

      # if app name is not specified, make sure that we will only have one to run
      XcodeUtils.remove_existing_apps(Illuminator::BuildArtifacts.instance.xcode) if app_name.nil?
      if builder.build_for_automation(options.xcode.sdk, hardware_id)
        puts 'Build succeded'.green
        options.instruments.app_location = Illuminator::BuildArtifacts.instance.app_location(app_name)
      else
        puts 'Build failed, check logs for results'.red
        exit builder.exit_code
      end
    end

    return true unless options.illuminator.task.automate

    # Install on real device
    unless hardware_id.nil?
      DeviceInstaller.instance.install_on_device(options.instruments.app_location, hardware_id)
    end

    # Initialize automation
    runner = AutomationRunner.new
    runner.app_name = app_name
    runner.cleanup
    return runner.run_with_options(options)

  end

  # override_options is a lambda function that acts on the options object
  def self.rerun(config_path, override_options = nil)

    # load config from supplied path
    json_config = IO.read(config_path)

    # process any overrides
    options = override_options.(Illuminator::Options.new(JSON.parse(json_config))) unless override_options.nil?

    return run_with_options options
  end


end
