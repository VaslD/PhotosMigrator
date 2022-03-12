platform :ios, "13.0"

use_frameworks!
inhibit_all_warnings!

target "Photos Migrator" do
  inherit! :search_paths

  pod "AcknowList", "~> 2.1.0"
  pod "MBProgressHUD", "~> 1.2.0"
  pod "SPAlert", "~> 2.1.4"
  pod "SPPermissions/PhotoLibrary", "~> 5.5.8"
  pod "WhatsNewKit", "~> 1.3.7"
end

post_install do |installer|
  # This is a workaround for CocoaPods issue 5334.
  # See discussions on: https://github.com/CocoaPods/CocoaPods/issues/5334#issuecomment-255831772
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = [
      "$(FRAMEWORK_SEARCH_PATHS)",
    ]
  end

  # Remove Xcode warnings on minimum deployment targets.
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if Gem::Version.new("9.0") > Gem::Version.new(config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"])
        config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "9.0"
      end
    end
  end
end
