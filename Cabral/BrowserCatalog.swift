import AppKit
import Observation
import UniformTypeIdentifiers

struct Browser: Identifiable, Hashable {
    let id: String  // bundle identifier
    let name: String
    let url: URL

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    var smallIcon: NSImage {
        let image = icon.copy() as! NSImage
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

@Observable
final class BrowserCatalog {
    private(set) var browsers: [Browser] = []

    init() { refresh() }

    /// Browsers = apps that open both https URLs and HTML files (drops apps that only
    /// claim https, like chat/terminal apps), excluding automation copies in caches.
    func refresh() {
        let own = Bundle.main.bundleIdentifier
        let workspace = NSWorkspace.shared
        let htmlViewers = Set(workspace.urlsForApplications(toOpen: .html).map(\.path))
        var seen = Set<String>()
        browsers = workspace.urlsForApplications(toOpen: URL(string: "https://example.com")!)
            .filter { htmlViewers.contains($0.path) && !$0.path.contains("/Caches/") && !$0.path.contains("/.cache/") }
            .compactMap { url -> Browser? in
                guard let id = Bundle(url: url)?.bundleIdentifier, id != own, seen.insert(id).inserted else { return nil }
                return Browser(id: id, name: url.deletingPathExtension().lastPathComponent, url: url)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func browser(_ id: String) -> Browser? {
        browsers.first { $0.id == id }
    }
}

enum DefaultBrowser {
    static var isCurrent: Bool {
        let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
        return handler.flatMap { Bundle(url: $0)?.bundleIdentifier } == Bundle.main.bundleIdentifier
    }

    /// macOS asks the user to confirm. Returns false if it fails or is declined.
    static func makeCurrent() async -> Bool {
        do {
            for scheme in ["http", "https"] {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
            }
            return true
        } catch {
            return false
        }
    }
}
