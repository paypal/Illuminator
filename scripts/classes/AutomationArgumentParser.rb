require File.join(File.expand_path(File.dirname(__FILE__)), 'PlistEditor.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationArgumentParserFactory.rb')

class AutomationArgumentParser
  def parse args

    options = {}
    myfn = lambda{|p| self.readFromPath p }
    parserFactory = AutomationParserFactory.new({
                                                  "x" => "defaultXcode",
                                                  "p" => "testPath",
                                                  "a" => "appName",
                                                  "t" => "tagsAny",
                                                  "o" => "tagsAll",
                                                  "n" => "tagsNone",
                                                  "s" => "scheme",
                                                  "j" => "plistSettingsPath",
                                                  "d" => "hardwareID",
                                                  "i" => "implementation",
                                                  "b" => "simdevice",
                                                  "z" => "simversion",
                                                  "l" => "simlanguage",
                                                  "f" => "skipBuild",
                                                  "e" => "skipSetSim",
                                                  "k" => "skipKillAfter",
                                                  "c" => "coverage",
                                                  "r" => "report",
                                                  "v" => "verbose",
                                                  "m" => "timeout",
                                                  "w" => "randomSeed",
                                                  "y" => "customArguments",
                                                },
                                                {
                                                  "j" => lambda {|p| (Pathname.new p).realpath().to_s },
                                                  "y" => lambda {|p| self.readFromPath p },
                                                })
    parser = parserFactory.buildParser(options, "xpatonsjdi#bzl#fek#crvmwy")

    begin parser.parse! ARGV
    rescue
    end

    return options
  end


  def readFromPath path
    storage = PLISTStorage.new
    return storage.readFromStorageAtPath path
  end


end
