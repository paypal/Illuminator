require File.join(File.expand_path(File.dirname(__FILE__)), 'PlistEditor.rb')

class AutomationArgumentParser
	def parse args, options
		

		####################################################################################################
		# parse arguments
		####################################################################################################
		
		parser = OptionParser.new do |opts|
			opts.banner = "Usage from workspace directory: ruby {pathTo UI-Automator}/scripts/automationTests.rb [options]"
			opts.separator "######################################################################"
			opts.on("-x", "--xcode PATH", "Sets path to default Xcode instalation ") do |path|
				options["defaultXcode"] = path
			end
			opts.on("-p", "--testPath PATH", "Path to js file with all tests imported") do |path|
				options["testPath"] = (Pathname.new path).realpath().to_s
			end
			opts.on("-a", "--appName APPNAME", "App name to run") do |v|
				options["appName"] = v
			end
			opts.on("-t", "--tags-any TAGSANY", "Run tests with any of the given tags") do |v|
				options["tagsAny"] = v
			end
			opts.on("-o", "--tags-all TAGSALL", "Run tests with all of the given tags") do |v|
				options["tagsAll"] = v
			end
			opts.on("-n", "--tags-none TAGSNONE", "Run tests with none of the given tags") do |v|
				options["tagsNone"] = v
			end
			opts.on("-s", "--scheme SCHEME", "Build and run specific tests on given workspace scheme") do |v|
				options["scheme"] = v
			end
			opts.on("-j", "--plistSettingsPath PATH", "path to settings plist") do |path|
				options["plistSettingsPath"] = (Pathname.new path).realpath().to_s
			end
			opts.on("-d", "--hardwareID ID", "hardware id of device you run on") do |v|
				options["hardwareID"] = v
			end
			opts.on("-i", "--implementation IMPL", "Device tests implementation (iPhone|iPad)") do |impl|
				options["implementation"] = impl
			end
		
		
			opts.separator "######################################################################"
		
			opts.on("-b", "--simdevice DEVICE", "Run on given simulated device           Defaults to \"iPhone Retina (4-inch)\"") do |v|
				options["simdevice"] = v
			end
				opts.on("-z", "--simversion VERSION", "Run on given simulated iOS version     Defaults to \"iOS 7.0\"") do |v|
				options["simversion"] = v
			end
			opts.on("-l", "--simlanguage LANGUAGE", "Run on given simulated iOS language     Defaults to \"en\"") do |v|
				options["simlanguage"] = v
			end
		
			opts.separator "######################################################################"
		
			opts.on("-f", "--skip-build", "Just automate; assume already built") do |v|
				options["skipBuild"] = TRUE
			end
			opts.on("-e", "--skip-set-sim", "Assume that simulator has already been chosen and properly reset") do |v|
				options["skipSetSim"] = TRUE
			end
			opts.on("-k", "--skip-kill-after", "Do not kill the simulator after the run") do |v|
				options["skipKillAfter"] = TRUE
			end
		
			opts.separator "######################################################################"
		
			opts.on("-c", "--coverage", "Generate coverage files") do |v|
				options["coverage"] = TRUE
			end
			opts.on("-r", "--report", "Generate Xunit reports in buildArtifacts/UIAutomationReport folder") do |v|
				options["report"] = TRUE
			end
			opts.on("-v", "--verbose", "Show verbose output") do |v|
				options["verbose"] = TRUE
			end
			opts.on("-m", "--timeout TIMEOUT", "startup timeout") do |v|
				options["timeout"] = v
			end
			opts.on("-w", "--random-seed SEED", "Randomize test order based on given integer seed") do |v|
				options["randomSeed"] = v
			end
			
			opts.on("-y", "--customArguments PARSER", "custom argument parser") do |parserPath|
				options = options.merge (self.readFromPath parserPath)
			end
			opts.on_tail("-h", "--help", "Show this message") do
				puts opts
				exit
			end
		end
		

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