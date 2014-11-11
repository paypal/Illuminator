
class HostUtils

  # Cross-platform way of finding an executable in the $PATH.
  # based on http://stackoverflow.com/a/5471032/2063546
  #
  #   which('ruby') #=> /usr/bin/ruby
  def self.which program
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each do |ext|
        exe = File.join(path, "#{program}#{ext}")
        return exe if File.executable?(exe) unless File.directory?(exe)
      end
    end
    return nil
  end

end
