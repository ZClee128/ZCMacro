Pod::Spec.new do |s|
  s.name             = 'ZCMacro'
  s.version          = '1.2.1'
  s.summary          = 'A proof of concept macro to show they can work with cocoapods.'
  s.description      = <<-DESC
A proof of concept macro to show they can work with cocoapods.
                       DESC
  s.homepage         = 'https://github.com/ZClee128/ZCMacro'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zclee' => '876231865@qq.com', }
  s.source           = { :git => 'https://github.com/ZClee128/ZCMacro', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  # 1
  s.source_files = ['Sources/ZCMacro/**/*']
  s.swift_version = "5.9"
  # 2
  s.preserve_paths = ["macros/ZCMacroMacros"]
  # 3
  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-load-plugin-executable ${PODS_ROOT}/ZCMacro/macros/ZCMacroMacros#ZCMacroMacros'
  }
#  s.pod_target_xcconfig = {
#   'OTHER_SWIFT_FLAGS' => '-load-plugin-executable /Users/yxd_mbp/Desktop/ng个人/ZCMacro/macros/ZCMacroMacros#ZCMacroMacros'
#  }
  # 4
  s.user_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-load-plugin-executable ${PODS_ROOT}/ZCMacro/macros/ZCMacroMacros#ZCMacroMacros'
  }
#  s.user_target_xcconfig = {
#    'OTHER_SWIFT_FLAGS' => '-load-plugin-executable /Users/yxd_mbp/Desktop/ng个人/ZCMacro/macros/ZCMacroMacros#ZCMacroMacros'
#  }
end
