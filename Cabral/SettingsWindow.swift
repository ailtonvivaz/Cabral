import AppKit
import SwiftUI

/// Dock icon only while this window is open; otherwise the app stays an accessory.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: Store
    private let catalog: BrowserCatalog
    private var window: NSWindow?

    init(store: Store, catalog: BrowserCatalog) {
        self.store = store
        self.catalog = catalog
    }

    func show() {
        catalog.refresh()
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().environment(store).environment(catalog))
            hosting.sizingOptions = []
            hosting.sceneBridgingOptions = [.toolbars]
            let window = NSWindow(contentViewController: hosting)
            window.title = "Cabral"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.toolbarStyle = .unified
            window.titleVisibility = .hidden
            window.contentMinSize = NSSize(width: 620, height: 420)
            window.setContentSize(NSSize(width: 680, height: 520))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            window.setFrameAutosaveName("SettingsWindow")
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        store.config.rules.removeAll { $0.domain.isEmpty }
        NSApp.setActivationPolicy(.accessory)
    }
}
