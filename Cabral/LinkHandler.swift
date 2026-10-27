import AppKit

final class LinkHandler {
    struct Link {
        let url: URL
        let sender: String?
    }

    private let store: Store
    private let catalog: BrowserCatalog
    /// `forced`: show the picker even if a rule now matches (the rule's browser just failed).
    private var queue: [(link: Link, forced: Bool)] = []
    private var picker: PickerPanel?

    init(store: Store, catalog: BrowserCatalog) {
        self.store = store
        self.catalog = catalog
    }

    func handle(_ link: Link) {
        let link = Link(url: LinkUnwrapper.unwrap(link.url), sender: link.sender)
        switch Router.resolve(link.url, in: store.config).action {
        case .browser(let id): open(link, with: id)
        case .ask: enqueue(link, forced: false)
        }
    }

    private func open(_ link: Link, with bundleID: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            showError(String(localized: "Browser not found"), String(localized: "\(bundleID) is not installed. Choose another browser."))
            return enqueue(link, forced: true)
        }
        Task {
            do {
                _ = try await NSWorkspace.shared.open([link.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
            } catch {
                showError(String(localized: "Couldn’t open the link"), error.localizedDescription)
                enqueue(link, forced: true)
            }
        }
    }

    private func enqueue(_ link: Link, forced: Bool) {
        queue.append((link, forced))
        showNextPicker()
    }

    private func showNextPicker() {
        guard picker == nil else { return }
        // Re-route on dequeue: a "remember" choice may have created a rule for queued links.
        while let next = queue.first {
            queue.removeFirst()
            if !next.forced, case .browser(let id) = Router.resolve(next.link.url, in: store.config).action {
                open(next.link, with: id)
            } else {
                return showPicker(for: next.link)
            }
        }
    }

    private func showPicker(for link: Link) {
        let host = Domain.normalize(link.url.absoluteString)
        catalog.refresh()
        picker = PickerPanel(link: link, host: host, browsers: catalog.browsers) { [weak self] choice in
            self?.finish(link, host: host, choice: choice)
        }
        picker?.show()
    }

    private func finish(_ link: Link, host: String, choice: PickerChoice?) {
        picker = nil
        if let choice {
            if choice.remember, !host.isEmpty {
                store.setAction(.browser(choice.browser.id), forDomain: host)
            }
            open(link, with: choice.browser.id)
        }
        showNextPicker()
    }

    private func showError(_ title: String, _ message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
