import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let catalog = BrowserCatalog()
    private lazy var links = LinkHandler(store: store, catalog: catalog)
    private lazy var settings = SettingsWindowController(store: store, catalog: catalog)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        // Launched by Finder/Dock/Spotlight, not to open a link.
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true {
            settings.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let sender = Self.senderName()
        for url in urls where ["http", "https"].contains(url.scheme?.lowercased()) {
            links.handle(.init(url: url, sender: sender))
        }
    }

    /// Name of the app that sent the open event, when it is a regular app.
    private static func senderName() -> String? {
        guard
            let pid = NSAppleEventManager.shared().currentAppleEvent?
                .attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value,
            pid != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }
}
