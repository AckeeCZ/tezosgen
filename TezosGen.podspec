Pod::Spec.new do |s|
    s.name             = 'TezosGen'
    s.version          = '0.2'
    s.summary          = 'Generate code from abi.json'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
    s.description      = "Generate code from abi.json using Swift tool."
  
    s.homepage         = 'https://github.com/AckeeCZ/Tezos-iOS-Dev-Kit.git'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Ackee' => 'info@ackee.cz' }
    s.source           = { :git => "https://github.com/AckeeCZ/Tezos-iOS-Dev-Kit.git", :tag => s.version.to_s }
    s.preserve_paths = 'TezosGen/**', 'LICENSE'
    s.ios.deployment_target = "10.0"
    s.swift_version = "4.2"
    s.dependency 'TezosSwift', '~> 0.1'
  end
  