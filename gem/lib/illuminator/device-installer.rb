require 'singleton'

require_relative './host-utils'

# Wrapper for possible methods of installing an app on physical hardware
class DeviceInstaller
  include Singleton

  def initialize
    installers = ['ios-deploy']

    @installedInstallers = {}
    installers.each { |exe| @installedInstallers[exe] = Illuminator::HostUtils.which(exe) }
  end


  def _installUsingIosDeploy(appLocation, hardwareID)
    # TODO: actually watch the output of this command
    cmd = "#{@installedInstallers['ios-deploy']} -b '#{appLocation}' -i #{hardwareID} -r -n"
    puts cmd.green
    puts `#{cmd}`
  end


  def installOnDevice(appLocation, hardwareID, specificMethod = nil)
    # if nothing is specified, just get the first one that exists
    if specificMethod.nil?
      @installedInstallers.each do |name, path|
        specificMethod = path
        break unless specificMethod.nil?
      end
    end

    # run the appropriate helper for doing this
    puts "Installing #{appLocation} on device #{hardwareID} using #{specificMethod}"
    case specificMethod
    when /ios-deploy$/
      self._installUsingIosDeploy(appLocation, hardwareID)
    else
      puts "None of the following utilities for app installation appear to be installed: #{@installedInstallers.keys.to_s}".red
      raise NotImplementedError, "No app installation available with name " + specificMethod.to_s
    end
  end

end
