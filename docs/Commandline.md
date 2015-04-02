The ILLUMINATOR Command Line
============================

Illuminator employs a Ruby script wrapper to Instruments, which imposes some order on the somewhat-unreliable Instruments binary and provides other capabilities such as simulator selection and JUnit reporting.

The Basic, Quick-Start Instant-Gratification Command
----------------------------------------------------

Included in the `scripts/` directory is `scripts/automationTests.rb` -- a script that exposes Illuminator's core options on the command line.

```
$ ruby scripts/automationTests.rb  --help
Usage: automationTests.rb [options]
    -a, --appName APPNAME            Name of the app to build / run
    -s, --scheme SCHEME              Build and run specific tests on given workspace scheme
    -d, --hardwareID ID              hardware id of device to run on instead of simulator
    -q, --sdk SDK                    SDK to build against   ::   Defaults to "iphonesimulator"
  ---------------------------------------------------------------------------------
    -x, --entryPoint LABEL           The execution entry point {runTestsByTag, runTestsByName, describe}   ::   Defaults to "runTestsByTag"
    -t, --tags-any TAGSANY           Run tests with any of the given tags
    -o, --tags-all TAGSALL           Run tests with all of the given tags
    -n, --tags-none TAGSNONE         Run tests with none of the given tags
    -i, --implementation IMPL        Device tests implementation
  ---------------------------------------------------------------------------------
    -r, --retest OPTIONS             Immediately retest failed tests with comma-separated options {1x, solo}
    -v, --verbose                    Show verbose output from instruments
    -m, --timeout TIMEOUT            Seconds to wait for instruments tool to start tests   ::   Defaults to "30"
    -w, --random-seed SEED           Randomize test order based on given integer seed
  ---------------------------------------------------------------------------------
    -b, --simDevice DEVICE           Run on given simulated device   ::   Defaults to "iPhone 5"
    -z, --simVersion VERSION         Run on given simulated iOS version   ::   Defaults to "8.2"
    -l, --simLanguage LANGUAGE       Run on given simulated iOS language   ::   Defaults to "en"
  ---------------------------------------------------------------------------------
    -B, --skip-automate              Don't automate; build only   ::   Defaults to "false"
    -f, --skip-build                 Just automate; assume already built   ::   Defaults to "false"
    -e, --skip-set-sim               Assume that simulator has already been chosen and properly reset   ::   Defaults to "false"
    -k, --skip-kill-after            Leave the simulator open after the run   ::   Defaults to "false"
  ---------------------------------------------------------------------------------
    -h, --help                       Show this help message

```

By simply pointing to your top-level Javascript file, this script can serve your needs for testing.

A Better Command-Line Script
----------------------------

Many of the options you want to send to Illuminator will be the same every time.  It would make sense to simply hard-code these values into your own command-line ruby script.

For example, the Illuminator [`smokeTests.rb`](../scripts/smokeTests.rb) script:

```ruby
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorOptions.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/HostUtils.rb')

# Change directory to sample app and use that for the workspace
Dir.chdir 'SampleApp/AutomatorSampleApp'
workspace = Dir.pwd

allTestPath = '../../SampleApp/SampleTests/tests/AllTests.js'
allTestPath = HostUtils.realpath(allTestPath)

# Hard-coded options

options = IlluminatorOptions.new
options.xcode.appName = 'AutomatorSampleApp'
options.xcode.scheme = 'AutomatorSampleApp'

options.illuminator.entryPoint = 'runTestsByTag'
options.illuminator.test.tags.any = ['smoke']
options.illuminator.clean.xcode = true
options.illuminator.clean.artifacts = true
options.illuminator.clean.noDelay = true
options.illuminator.task.build = true
options.illuminator.task.automate = true
options.illuminator.task.setSim = true
options.simulator.device = 'iPhone 5'
options.simulator.language = 'en'
options.simulator.killAfter = true

options.instruments.doVerbose = false
options.instruments.timeout = 30

options.javascript.testPath = allTestPath
options.javascript.implementation = 'iPhone'

if XcodeUtils.instance.isXcodeMajorVersion 5
  options.simulator.device = 'iPhone Retina (4-inch)'
end

options.simulator.version = '8.1'
success8 = IlluminatorFramework.runWithOptions options, workspace

options.illuminator.clean.artifacts = false
options.illuminator.task.build = false
options.simulator.version = '7.1'
success7 = IlluminatorFramework.runWithOptions options, workspace

exit 1 unless success7 and success8

```

In short:
1. a `workspace` directory is chosen
2. the options object is created with `IlluminatorOptions.new`
3. the object is filled in with values _(see below)_
4. the framework is run using the options and workspace, with `IlluminatorFramework.runWithOptions options, workspace`
5. the framework returns a result which in turn is passed to the shell


Illuminator Options
--------------------

The following options are defined in Illuminator (assuming `options = IlluminatorOptions.new`).


### Xcode options

#### `options.xcode.project` (string)
The project name to build, available in the directory identified by the `workspace` parameter.  This argument is optional unless you have more than one project in the `workspace` directory.

#### `options.xcode.appName` (string)
The name of the application that will be built by Xcode (and run by Instruments)

#### `options.xcode.sdk` (string)
The SDK that will be used by Xcode.  This defaults to `iphonesimulator` for simulator runs, and `iphoneos` for real hardware runs, so there should be no reason to supply it manually.

#### `options.xcode.scheme` (string)
The scheme to build, corresponding to a scheme in the given Xcode project.

#### `options.xcode.environmentVars` (hash)
A hash of any project-specific environment variables that should be specified on the `xcodebuild` command line.


### Illuminator options

#### `options.illuminator.entryPoint` (string)
The major function that will be performed by Illuminator -- can be one of `runTestsByTag`, `runTestsByName`, `describe`.
* `runTestsByTag` parses the three `.test.tags.*` options (below) to decide which set of tests should be run
* `runTestsByName` uses the `.test.names` option for the list of tests to run
* `describe` simply prints out descriptions of the test environment for documentation or debugging purposes.

#### `options.illuminator.test.randomSeed` (integer)
If provided, Illuminator uses this value as a seed to randomize the order of the test runs.

#### `options.illuminator.test.tags.any` (string array)
Under the `runTestsByTag` entry point, this option specifies that any tests with a tag in this list will be selected to run, unless overridden by one of the other two `.test.tags.*` options.

#### `options.illuminator.test.tags.all` (string array)
Under the `runTestsByTag` entry point, this option specifies that only tests that include _all_ tags in this list will be selected to run.

#### `options.illuminator.test.tags.none` (string array)
Under the `runTestsByTag` entry point, this option specifies that any tests that include _any_ tags in this list will **not** be selected to run.

#### `options.illuminator.test.names` (string array)
Under the `runTestsByName` entry point, this option specifies the list of tests (in order) that should be run.

#### `options.illuminator.test.retest.attempts` (integer)
Under the `runTestsByTag` and `runTestsByName` entry point, this specifies the number of times that failed tests will be re-tested.

#### `options.illuminator.test.retest.solo` (boolean)
When retesting failed tests, this option specifies that they should be run in their own individual Instruments instance, without any other tests.

#### `options.illuminator.clean.xcode` (boolean)
This option specfies that `xcodebuild` should clean the project before building.

#### `options.illuminator.clean.derived` (boolean)
This option specifies that the `DerivedData` directory should be deleted before building.

#### `options.illuminator.clean.artifacts` (boolean)
This option specifies that the entire Illuminator `buildArtifacts` (output) directory should be deleted before building.

#### `options.illuminator.clean.noDelay` (boolean)
This option specifes that the default 3-second command-line countdown (giving you a chance to abort any directory deletions) will be skipped.

#### `options.illuminator.task.build` (boolean)
This option specifies that the Xcode project should be built before automating, even if it has already been built.

#### `options.illuminator.task.automate` (boolean)
This option specifies that the Instruments automation should run.

#### `options.illuminator.task.setSim` (boolean)
This option specifies that Illuminator should select and reset the simulator from the command line.

#### `options.illuminator.task.coverage` (boolean)
This option specifies that `gcovr` should be run after the automation completes, to determine coverage.  This coverage report will only include the last set of tests that ran without crashing.

#### `options.illuminator.hardwareID` (string)
This option specifies that the automation should run on physical hardware, specified by the ID.


### Simulator options

#### `options.simulator.device` (string)
This option selects the simulator device that should be run.

#### `options.simulator.version` (string)
This option selects the iOS version of the simulator.

#### `options.simulator.language` (string)
This option selects the language of the simulator (currently unsupported).

#### `options.simulator.killAfter` (boolean)
This option specifies whether to close the simulator after automation is complete.


### Instruments options

#### `options.instruments.doVerbose` (boolean)
This option specifies whether verbose output (vs pretty output) of Instruments is sent to the console.  Full output of Instruments is logged to disk regardless.

#### `options.instruments.timeout` (integer)
The number of seconds to spend waiting for Instruments to start up and begin executing the Javascript code, before simply killing it and starting again.

#### `options.instruments.attempts` (integer)
The number of times to attempt starting and restarting Instruments before giving up.
> Under Xcode 5, this number needed to be set as high as 30.  No joke.


#### `options.instruments.appLocation` (string)
The location of the compiled application that Instruments will automate.  This option should be specified if you are automating a pre-built binary; otherwise, Illuminator defaults to using the application that it built itself.

### Javascript options

#### `options.javascript.testPath` (string)
The location of the Javascript file containing your top-level entry point.  This file should define (or import) all the tests that you have defined.  The specific tests to run will be determined by the `entryPoint`.

#### `options.javascript.appSpecificConfig` (hash)
A hash of values that will be passed into the Javascript environment, made available under `config.customConfig`.  Yes, **Illuminator can pass structured values directly from Ruby, through Instruments, into Javascript**.

#### `options.javascript.implementation` (string)
The implementation to use when automating.  This should match one of the implementations you defined in your [`AppMap`](AppMap.md).



Using and Extending the Illuminator Argument Parser
---------------------------------------------------

Here is an example of how to mix hard-coded values with Illuminator command-line options, as well as custom command-line options.

```ruby
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorArgumentParsing.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/HostUtils.rb')

workspace = Dir.pwd

# Set up the default parser
parserFactory = IlluminatorParserFactory.new

# Prepare the parser.  We will add the switch -g, aka --word-starting-with-g
#   and override -p, aka --ipad to be a simple switch for iPad testing

                       # default values for all the named switches
parserFactory.prepare({"g" => "gundalow", "i" => "myImplementation", "s" => "iPhone", "a" => "My App", "b" => 'iPhone Retina (4-inch)'},
                       # the keys in the output array that will store the values for these command line switches
                      {"g" => "word-starting-with-g", "p" => "do-ipad"},
                       # Custom processing for any switches.  Since we're overriding 'p', we need to nil-out any processing function for it
                      {"p" => nil})
# Add our custom switch, and the replacement switch
parserFactory.addSwitch("g", ["-g", "--word-starting-with-g WORD", "A word starting with G, for fun"])
parserFactory.addSwitch("p", ["-p", "--do-ipad", "Run ipad implementation"])

# build the parser using letters from IlluminatorArgumentParsing plus our custom ones
parser = parserFactory.buildParser({}, "xtondispaE#bzl#fBeky#crvmw#g")

# Now use the parser to get input arguments
options = parser.parse ARGV


options.javascript.testPath = HostUtils.realpath("path/to/my/AllTests.js")

# Storing our custom value in custom javascript config
storage = {}
storage["gWord"] = options.appSpecific["word-starting-with-g"]
options.javascript.appSpecificConfig = storage

# Setting up several settings at once if iPad was specfied##########################################

if options.appSpecific["do-ipad"]
  options.xcode.appName = "My App HD"
  options.xcode.scheme = "iPad"
  options.javascript.implementation = "iPad"
  unless options.simulator.device.start_with? "iPad"
    options.simulator.device = 'iPad'
    if XcodeUtils.instance.isXcodeMajorVersion 6
      options.simulator.device = "iPad 2"
    end
  end
end

# Run it
success = IlluminatorFramework.runWithOptions options, workspace
exit 1 unless success
```

The strangest piece of this code is probably the `"xtondispaE#bzl#fBeky#crvmw#g"`.  This tells the Parser Factor which command line switches to use (by their single-letter code), and the order in which to list them in the help file (`#` indicating separators).

The second-strangest piece of code is probably the `parserFactory.prepare` line.  If you're reading this far, you should [make contact via one of the Help channels listed in the README](../README.md) and ask for help, so that I can improve this documentation based on your questions.  But the comments in [IlluminatorArgumentParsing.rb](../scripts/classes/IlluminatorArgumentParsing.rb) should help somewhat.