import AppKit
import Observation
import Sparkle

/// Sparkle wrapper. Nothing touches the network unless the user checks by hand or
/// accepts automatic checks (Sparkle asks once, on the second launch).
@Observable
final class Updater: NSObject {
    /// False in builds without an EdDSA public key (forks, CI): Sparkle never starts there.
    let isAvailable: Bool
    private(set) var canCheckForUpdates = false
    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?

    override init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        isAvailable = !key.trimmingCharacters(in: .whitespaces).isEmpty
        super.init()
        guard isAvailable else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
            [weak self] updater, _ in
            // Sparkle changes this property on the main thread.
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller?.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller?.checkForUpdates(sender)
    }
}

extension Updater: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action == #selector(checkForUpdates(_:)) ? canCheckForUpdates : true
    }
}
