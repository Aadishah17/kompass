#!/usr/bin/env ruby

require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PACKAGE_DIR = File.join(ROOT, "kompass.swiftpm")
PROJECT_PATH = File.join(ROOT, "Kompass.xcodeproj")
TEAM_ID = "W4CGNMV2HK"
DEPLOYMENT_TARGET = "17.0"

APP_GROUPS = {
  "App" => %w[MyApp.swift ContentView.swift],
  "Views" => %w[CompassView.swift MapView.swift BottomSheetView.swift DynamicIslandView.swift LocationDetailView.swift TransitDetailView.swift TransportModeView.swift RouteComparisonView.swift],
  "Models" => %w[Location.swift NavigationAttributes.swift OfflineCities.swift PlaceCategory.swift SearchResult.swift],
  "Services" => %w[LocationManager.swift NavigationLiveActivityManager.swift NetworkManager.swift RideShareService.swift RouteAgentCoordinator.swift SearchCompleter.swift]
}.freeze

WIDGET_GROUPS = {
  "Widget" => %w[KompassNavigationWidgetBundle.swift LiveActivityWidget.swift]
}.freeze

# NavigationAttributes needs to be in Widget target as well, but it's physically in Models.
SHARED_SOURCES = {
  "Models" => %w[NavigationAttributes.swift]
}.freeze

SUPPORT_FILES = {
  app_info: "XcodeSupport/App/Info.plist",
  widget_info: "XcodeSupport/Widget/Info.plist"
}.freeze

def apply_shared_build_settings(target, bundle_id:, info_plist:, device_families:)
  target.build_configurations.each do |config|
    config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    config.build_settings["DEVELOPMENT_TEAM"] = TEAM_ID
    config.build_settings["SWIFT_VERSION"] = "6.0"
    config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = DEPLOYMENT_TARGET
    config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
    config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
    config.build_settings["MARKETING_VERSION"] = "1.0"
    config.build_settings["INFOPLIST_FILE"] = info_plist
    config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
    config.build_settings["TARGETED_DEVICE_FAMILY"] = device_families
    config.build_settings["ENABLE_PREVIEWS"] = "YES"
    config.build_settings["SWIFT_EMIT_LOC_STRINGS"] = "YES"
    config.build_settings["CLANG_ENABLE_MODULES"] = "YES"
  end
end

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastUpgradeCheck"] = "2630"
project.root_object.attributes["TargetAttributes"] ||= {}

project.build_configurations.each do |config|
  config.build_settings["DEVELOPMENT_TEAM"] = TEAM_ID
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = DEPLOYMENT_TARGET
  config.build_settings["SWIFT_VERSION"] = "6.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["CLANG_ENABLE_MODULES"] = "YES"
end

package_group = project.main_group.new_group("kompass.swiftpm", "kompass.swiftpm")
support_group = project.main_group.new_group("XcodeSupport", "XcodeSupport")
project.main_group.set_source_tree("<group>")

app_target = project.new_target(:application, "Kompass", :ios, DEPLOYMENT_TARGET)
widget_target = project.new_target(:app_extension, "KompassNavigationWidgetExtension", :ios, DEPLOYMENT_TARGET)

project.root_object.attributes["TargetAttributes"][app_target.uuid] = {
  "DevelopmentTeam" => TEAM_ID,
  "ProvisioningStyle" => "Automatic"
}
project.root_object.attributes["TargetAttributes"][widget_target.uuid] = {
  "DevelopmentTeam" => TEAM_ID,
  "ProvisioningStyle" => "Automatic"
}

apply_shared_build_settings(
  app_target,
  bundle_id: "com.aadishah.kompass",
  info_plist: SUPPORT_FILES[:app_info],
  device_families: "1,2"
)
apply_shared_build_settings(
  widget_target,
  bundle_id: "com.aadishah.kompass.navigation-widget",
  info_plist: SUPPORT_FILES[:widget_info],
  device_families: "1"
)

app_target.build_configurations.each do |config|
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = [
    "$(inherited)",
    "@executable_path/Frameworks"
  ]
end

widget_target.build_configurations.each do |config|
  config.build_settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = [
    "$(inherited)",
    "@executable_path/Frameworks",
    "@executable_path/../../Frameworks"
  ]
  config.build_settings["SKIP_INSTALL"] = "YES"
end

# Create proper groups and add files for App Target
file_refs_cache = {}

APP_GROUPS.each do |group_name, files|
  group = package_group.new_group(group_name, group_name)
  files.each do |file|
    file_ref = group.new_file(file)
    file_refs_cache["#{group_name}/#{file}"] = file_ref
    app_target.add_file_references([file_ref])
  end
end

# Create groups and add files for Widget Target
WIDGET_GROUPS.each do |group_name, files|
  group = package_group.new_group(group_name, group_name)
  files.each do |file|
    file_ref = group.new_file(file)
    file_refs_cache["#{group_name}/#{file}"] = file_ref
    widget_target.add_file_references([file_ref])
  end
end

# Link shared sources to Widget target (already added to project tree by APP_GROUPS)
SHARED_SOURCES.each do |group_name, files|
  files.each do |file|
    file_ref = file_refs_cache["#{group_name}/#{file}"]
    if file_ref
      widget_target.add_file_references([file_ref])
    end
  end
end

assets_ref = package_group.new_file("Assets.xcassets")
app_target.resources_build_phase.add_file_reference(assets_ref)

support_group.new_file("App/Info.plist")
support_group.new_file("Widget/Info.plist")

app_target.add_dependency(widget_target)
embed_phase = app_target.copy_files_build_phases.find { |phase| phase.name == "Embed App Extensions" } ||
  app_target.new_copy_files_build_phase("Embed App Extensions")
embed_phase.dst_subfolder_spec = "13"
embed_build_file = embed_phase.add_file_reference(widget_target.product_reference)
embed_build_file.settings = { "ATTRIBUTES" => %w[RemoveHeadersOnCopy] }

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.set_launch_target(app_target)
scheme.save_as(PROJECT_PATH, "Kompass", true)
