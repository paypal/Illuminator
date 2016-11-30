
Pod::Spec.new do |s|
  s.name             = "Illuminator"
  s.version          = "1.0.0"
  s.summary          = "ILLUMINATOR - the iOS Automator"
  s.description      = <<-DESC
                         Illuminator enables continuous integration for iOS apps.
                         It makes it easy (well, easier) to write and debug
                         sophisticated app tests. Additionally, it makes the
                         entire UIAutomation apparatus more capable of handling
                         high-volume automated testing
                       DESC
  s.homepage         = "https://github.com/paypal/Illuminator"
  s.license          = 'Apache License, Version 2.0'
  s.author           = ["Boris Erceg", "Ian Katz"]
  s.source       = { :git => "https://github.com/paypal/Illuminator.git", :tag => s.version.to_s }
  s.platform     = :ios, '9.0'
  s.requires_arc = true

  # s.resource_bundles = {
  #   'Illuminator' => ['Pod/Assets/*.png']
  # }

  s.ios.frameworks        = 'XCTest'
  s.ios.deployment_target = '8.0'
  s.source_files          = 'Pod/Illuminator/**/*.{c,h,hh,m,mm,swift}'

end
