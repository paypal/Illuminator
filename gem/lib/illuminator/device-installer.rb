require 'singleton'

require_relative './host-utils'

# Wrapper for possible methods of installing an app on physical hardware
class DeviceInstaller
  include Singleton

  def initialize
    installers = ['ios-deploy']

    @installed_installers = {}
    installers.each { |exe| @installed_installers[exe] = Illuminator::HostUtils.which(exe) }
  end


  def _install_using_ios_deploy(app_location, hardware_id)
    # TODO: actually watch the output of this command
    cmd = "#{@installed_installers['ios-deploy']} -b '#{app_location}' -i #{hardware_id} -r -n"
    puts cmd.green
    puts `#{cmd}`
  end


  def install_on_device(app_location, hardware_id, specific_method = nil)
    # if nothing is specified, just get the first one that exists
    if specific_method.nil?
      @installed_installers.each do |name, path|
        specific_method = path
        break unless specific_method.nil?
      end
    end

    # run the appropriate helper for doing this
    puts "Installing #{app_location} on device #{hardware_id} using #{specific_method}"
    case specific_method
    when /ios-deploy$/
      self._install_using_ios_deploy(app_location, hardware_id)
    else
      puts "None of the following utilities for app installation appear to be installed: #{@installed_installers.keys.to_s}".red
      raise NotImplementedError, "No app installation available with name " + specific_method.to_s
    end
  end

end
