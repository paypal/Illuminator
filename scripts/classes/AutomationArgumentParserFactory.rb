require 'ostruct'

class AutomationParserFactory

  # the currency of this parser factory is the "short" single-letter argument switch
  def initialize()
    @options = nil
    @switches = {}

    # build the list of how each parameter will be saved in the output
    @letterMap = {
      'p' => 'testPath',
      'a' => 'appName',
      't' => 'tagsAny',
      'o' => 'tagsAll',
      'n' => 'tagsNone',
      's' => 'scheme',
      'j' => 'plistSettingsPath',
      'd' => 'hardwareID',
      'i' => 'implementation',
      'b' => 'simDevice',
      'z' => 'simVersion',
      'l' => 'simLanguage',
      'f' => 'skipBuild',
      'e' => 'skipSetSim',
      'k' => 'skipKillAfter',
      'c' => 'coverage',
      'r' => 'report',
      'v' => 'verbose',
      'm' => 'timeout',
      'w' => 'randomSeed',
      'y' => 'skipClean',
    }

    @letterProcessing = {
      'j' => lambda {|p| (Pathname.new p).realpath().to_s },     # get real path to pList
    }

    @defaultValues = {'i'=> 'iPhone',
                      'b' => 'iPhone 6',
                      'z' => '8.1',
                      'l' => 'en',
                      'm' => 30 }
  end

  # you must custom prepare before you can add custom switches... otherwise things get all stupid
  def prepare(defaultValues = nil, letterMapUpdates = nil, letterProcessingUpdates = nil)
    @letterMap = @letterMap.merge(letterMapUpdates) unless letterMapUpdates.nil?
    @letterProcessing = @letterProcessing.merge(letterProcessingUpdates) unless letterProcessingUpdates.nil?
    @defaultValues = @defaultValues.merge defaultValues unless defaultValues.nil?

    self.addSwitch('p', ['-p', '--testPath PATH', 'Path to js file with all tests imported'])
    self.addSwitch('a', ['-a', '--appName APPNAME', "Name of the app to run"])
    self.addSwitch('t', ['-t', '--tags-any TAGSANY', 'Run tests with any of the given tags'])
    self.addSwitch('o', ['-o', '--tags-all TAGSALL', 'Run tests with all of the given tags'])
    self.addSwitch('n', ['-n', '--tags-none TAGSNONE', 'Run tests with none of the given tags'])
    self.addSwitch('s', ['-s', '--scheme SCHEME', 'Build and run specific tests on given workspace scheme'])
    self.addSwitch('j', ['-j', '--plistSettingsPath PATH', 'path to settings plist'])
    self.addSwitch('d', ['-d', '--hardwareID ID', 'hardware id of device you run on'])
    self.addSwitch('i', ['-i', '--implementation IMPL', 'Device tests implementation (iPhone|iPad)'])
    self.addSwitch('b', ['-b', '--simDevice DEVICE', 'Run on given simulated device'])
    self.addSwitch('z', ['-z', '--simVersion VERSION', 'Run on given simulated iOS version'])
    self.addSwitch('l', ['-l', '--simLanguage LANGUAGE', 'Run on given simulated iOS language'])
    self.addSwitch('f', ['-f', '--skip-build', 'Just automate; assume already built'])
    self.addSwitch('e', ['-e', '--skip-set-sim', 'Assume that simulator has already been chosen and properly reset'])
    self.addSwitch('k', ['-k', '--skip-kill-after', 'Do not kill the simulator after the run'])
    self.addSwitch('y', ['-y', '--skip-clean', 'Skip clean when building'])
    self.addSwitch('c', ['-c', '--coverage', 'Generate coverage files'])
    self.addSwitch('r', ['-r', '--report', 'Generate Xunit reports in buildArtifacts/UIAutomationReport folder'])
    self.addSwitch('v', ['-v', '--verbose', 'Show verbose output'])
    self.addSwitch('m', ['-m', '--timeout TIMEOUT', 'startup timeout'])
    self.addSwitch('w', ['-w', '--random-seed SEED', 'Randomize test order based on given integer seed'])
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
        if (!altered and item.chars.first != '-')
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
      letters = switches.keys.join('')
    end

    # helpful error message for bad chars
    bad_chars = letters.chars.to_a.select{|c| c != "#" and @switches[c].nil?}
    raise ArgumentError, "buildParser got letters (" + letters + ") containing unknown option characters: " + bad_chars.to_s unless bad_chars.empty?

    retval = OptionParser.new

    # build a parser as specified by the user
    letters.each_char do |c|
      options[self.getLetterDestination(c)] = @defaultValues[c] unless @defaultValues[c].nil?

      if c == '#'
        retval.separator('  ---------------------------------------------------------------------------------')
      else
        retval.on(*(@switches[c].send(:opts))) {|foo| @switches[c].send(:block).call(foo)}
      end
    end

    # help message is hard coded!
    retval.on_tail('-h', '--help', 'Show this help message') {|foo| puts retval.help(); exit  }

    #puts retval
    return retval
  end

end
