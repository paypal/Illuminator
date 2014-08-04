ILLUMINATOR - the iOS Automator
===============================

Illuminator enables [continuous integration](http://en.wikipedia.org/wiki/Continuous_integration) for iOS apps.  It makes it easy (well, easier) to write and debug sophisticated app tests.  Additionally, it makes the entire UIAutomation apparatus more capable of handling high-volume automated testing -- providing features that are missing from Apple's "Instruments" application.


Top 3 features
--------------

#### 1. Ease of accessing and interacting with UI elements

Illuminator is inspired by [tuneup.js](https://github.com/alexvollmer/tuneup_js) and [mechanic.js](https://github.com/jaykz52/mechanic), combining and improving [the best features of both](docs/Extensions.md).  Accessing UI elements can be done relative to a root element, by a fuzzy search of the element tree (easily extensible for app-specific capabilities), or by some combination of the two -- even if the element has not yet appeared on the screen.

#### 2. Ease of scripting and executing test scenarios across different target devices

[Test scenarios in Illuminator](docs/Automator.md) are easy to create and easy to read (and if you need to generate hundreds of test cases, it can be done programmatically instead of manually).  Managing a large test bank is simple as well; Illuminator can run test scenarios by name or by tag, and (intelligently) on either iPad or iPhone targets.  Illuminator can even complete test runs in which the app crashes during one of the tests.

#### 3. The ability to remote-control your app

There are some test actions that can't be done through screen interactions alone (e.g. events that would put your app into the background; anything involving the camera, microphone, or other external devices; triggering network events to happen at planned intervals).  Illuminator [provides an RPC channel](docs/Bridge.md) to expose these interactions -- enabling data to be passed betweent the app and the test script as appropriate.


Other Features
--------------

* [JUnit](http://windyroad.com.au/2011/02/07/apache-ant-junit-xml-schema/)-formatted test reports
* [Cobertura](http://cobertura.github.io/cobertura/)-formatted coverage reports
* Screenshot comparison capability with the ability to mask certain screen areas


Installation
------------

* Run `bundle install` to set up ruby gems


Further Documentation
---------------------
* [Quick start guide](docs/README.md)
* [Working with elements](docs/Extensions.md)
* [Defining screens](docs/AppMap.md)
* [Writing tests](docs/Automator.md)
* [Ruby scripts](docs/Commandline.md)
* [The RPC channel](docs/Bridge.md)
* [Troubleshooting](docs/Troubleshooting.md)
