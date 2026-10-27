import AppKit

// As a test host the app stays inert: no Settings window, no real config touched.
let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
let delegate: AppDelegate? = isTestHost ? nil : AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
