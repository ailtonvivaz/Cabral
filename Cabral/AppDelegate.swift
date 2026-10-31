import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let catalog = BrowserCatalog()
    private lazy var links = LinkHandler(store: store, catalog: catalog)
    private lazy var settings = SettingsWindowController(store: store, catalog: catalog)
    /// When the last Handoff started. A Handoff launch also reports itself as a default
    /// launch and can send a reopen, neither of which should open Settings.
    private var handoffStart: Date?

    private var inHandoff: Bool {
        handoffStart.map { Date.now.timeIntervalSince($0) < 5 } ?? false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        // Launched by Finder/Dock/Spotlight, not to open a link. Wait briefly: a Handoff
        // launch looks the same and its activity only arrives after this point.
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                if !inHandoff { settings.show() }
            }
        }
    }

    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        if userActivityType == NSUserActivityTypeBrowsingWeb { handoffStart = .now }
        return false  // Let AppKit show its default progress indication.
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !inHandoff { settings.show() }
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

    /// Handoff of a web page from another device, such as Safari on iPhone.
    func application(
        _ application: NSApplication, continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL,
            ["http", "https"].contains(url.scheme?.lowercased())
        else { return false }
        links.handle(.init(url: url, sender: String(localized: "Handoff"), atPointer: false))
        return true
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
