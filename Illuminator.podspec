
Pod::Spec.new do |s|
  s.name         = "Illuminator"
  s.version      = "0.0.1"
  s.summary      = "ILLUMINATOR - the iOS Automator"

  s.description  = <<-DESC
  Illuminator enables continuous integration for iOS apps. It makes it easy (well, easier) to write and debug sophisticated app tests. Additionally, it makes the entire UIAutomation apparatus more capable of handling high-volume automated testing -- providing features that are missing from Apple's "Instruments" application.
                   DESC

  s.homepage     = "https://github.com/paypal/illuminator"
  s.license            = 'Apache License, Version 2.0'
  s.author             = "PayPal"
  s.platform     = :ios
  s.source       = { :git => "https://github.com/kviksilver/Illuminator.git", :tag => "0.0.1" }
  s.source_files  = "PPAutomationBridge/*.{h,m}"
  s.resources =  "src/*"
  
end
