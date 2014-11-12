require 'pathname'

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

  def self.saveJSON(hashObject, path)
    f = File.open(path, 'w')
    f << JSON.pretty_generate(hashObject)
    f.close
  end

  # try to simplify the path, if it exists
  def self.realpath(path)
    epath = File.expand_path path

    # use expanded path if regular one fails
    path = epath unless (File.exists? path) or (File.directory? path)

    # use given path if it doesn't exist (can't take a real path of a nonexistent path)
    return path unless (File.exists? path) or (File.directory? path)

    Pathname.new(path).realpath.to_s
  end

end
