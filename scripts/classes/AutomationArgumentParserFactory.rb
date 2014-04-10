require 'ostruct'

class AutomationParserFactory

  # the currency of this parser factory is the "short" single-letter argument switch
  def initialize()
    @options = nil
    @switches = {}

    # build the list of how each parameter will be saved in the output
    @letterMap = {
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
    }

    @letterProcessing = {
      "j" => lambda {|p| (Pathname.new p).realpath().to_s },     # get real path to pList
    }

    @defaultValues = {}
  end

  # you must custom prepare before you can add custom switches... otherwise things get all stupid
  def prepare(defaultValues = nil, letterMapUpdates = nil, letterProcessingUpdates = nil)
    @letterMap = @letterMap.merge(letterMapUpdates) unless letterMapUpdates.nil?
    @letterProcessing = @letterProcessing.merge(letterProcessingUpdates) unless letterProcessingUpdates.nil?
    @defaultValues = defaultValues unless defaultValues.nil?

    self.addSwitch("x", ["-x", "--xcode PATH", "Sets path to default Xcode installation "])
    self.addSwitch("p", ["-p", "--testPath PATH", "Path to js file with all tests imported"])
    self.addSwitch("a", ["-a", "--appName APPNAME", "App name to run"])
    self.addSwitch("t", ["-t", "--tags-any TAGSANY", "Run tests with any of the given tags"])
    self.addSwitch("o", ["-o", "--tags-all TAGSALL", "Run tests with all of the given tags"])
    self.addSwitch("n", ["-n", "--tags-none TAGSNONE", "Run tests with none of the given tags"])
    self.addSwitch("s", ["-s", "--scheme SCHEME", "Build and run specific tests on given workspace scheme"])
    self.addSwitch("j", ["-j", "--plistSettingsPath PATH", "path to settings plist"])
    self.addSwitch("d", ["-d", "--hardwareID ID", "hardware id of device you run on"])
    self.addSwitch("i", ["-i", "--implementation IMPL", "Device tests implementation (iPhone|iPad)"])
    self.addSwitch("b", ["-b", "--simdevice DEVICE", "Run on given simulated device"])
    self.addSwitch("z", ["-z", "--simversion VERSION", "Run on given simulated iOS version"])
    self.addSwitch("l", ["-l", "--simlanguage LANGUAGE", "Run on given simulated iOS language"])
    self.addSwitch("f", ["-f", "--skip-build", "Just automate; assume already built"])
    self.addSwitch("e", ["-e", "--skip-set-sim", "Assume that simulator has already been chosen and properly reset"])
    self.addSwitch("k", ["-k", "--skip-kill-after", "Do not kill the simulator after the run"])
    self.addSwitch("c", ["-c", "--coverage", "Generate coverage files"])
    self.addSwitch("r", ["-r", "--report", "Generate Xunit reports in buildArtifacts/UIAutomationReport folder"])
    self.addSwitch("v", ["-v", "--verbose", "Show verbose output"])
    self.addSwitch("m", ["-m", "--timeout TIMEOUT", "startup timeout"])
    self.addSwitch("w", ["-w", "--random-seed SEED", "Randomize test order based on given integer seed"])
  end

  # add a parse switch for the given letter key, using the given options.
  #   the parse action is defined by the existence of letterProcessing for the letter key,
  #   which by default is simple assignment
  def addSwitch(letter, opts)
    dest = self.getLetterDestination(letter)

    # alter opts to include the default values
    altered = false
    if @defaultValues[letter]
      opts_with_default = opts.map do |item|
        if (!altered and item.chars.first != "-")
          item += "        Defaults to \"#{@defaultValues[letter]}\""
          altered = true
        end
        item
      end
    else
      opts_with_default = opts
    end

    @switches[letter] = OpenStruct.new(:opts => opts_with_default,
                                       :block => lambda do |newval|
                                         # assign the parsed value to the output, processing it if necessary
                                         if @letterProcessing[letter]
                                           @options[dest] = @letterProcessing[letter].call(newval)
                                         else
                                           @options[dest] = newval
                                         end
                                       end)
  end


  # letter destination defaults to the letter itself, but can be overwritten by letterMap
  def getLetterDestination(letter)
    return @letterMap[letter]? @letterMap[letter] : letter
  end


  # factory function
  def buildParser(options, letters = nil)
    @options = options

    if letters.nil?
      letters = switches.keys.join("")
    end

    retval = OptionParser.new

    # build a parser as specified by the user
    letters.each_char do |c|
      if c == "#"
        retval.separator("  ---------------------------------------------------------------------------------")
      else
        retval.on(*(@switches[c].send(:opts))) {|foo| @switches[c].send(:block).call(foo)}
      end
    end

    # help message is hard coded!
    retval.on_tail("-h", "--help", "Show this help message") {|foo| puts retval.help(); exit  }

    #puts retval
    return retval
  end

end
