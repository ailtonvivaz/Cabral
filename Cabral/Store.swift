import Foundation
import Observation
import os

private let logger = Logger(subsystem: "app.vivaz.Cabral", category: "store")

@Observable
final class Store {
    var config: Config { didSet { save() } }

    nonisolated static let defaultFileURL = URL.applicationSupportDirectory
        .appending(path: "Cabral", directoryHint: .isDirectory)
        .appending(path: "config.json")

    private let fileURL: URL
    /// False when a file exists that could not be read or moved aside: saving would destroy it.
    private let canSave: Bool

    init(fileURL: URL = Store.defaultFileURL) {
        self.fileURL = fileURL
        (config, canSave) = Self.load(from: fileURL)
    }

    func setAction(_ action: Action, forDomain domain: String) {
        if let index = config.rules.firstIndex(where: { $0.domain == domain }) {
            config.rules[index].action = action
        } else {
            config.rules.append(Rule(domain: domain, action: action))
        }
    }

    private static func load(from fileURL: URL) -> (Config, canSave: Bool) {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            if !FileManager.default.fileExists(atPath: fileURL.path) { return (Config(), true) }
            logger.error("Config exists but could not be read; not saving changes: \(error)")
            return (Config(), false)
        }
        do {
            return (try JSONDecoder().decode(Config.self, from: data), true)
        } catch {
            // The next save would overwrite the user's rules, so keep the unreadable file next to it.
            let stamp = Date().formatted(.iso8601.timeSeparator(.omitted))
            let backup = fileURL.deletingLastPathComponent().appending(path: "config.corrupt-\(stamp).json")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
                logger.error("Unreadable config moved to \(backup.lastPathComponent, privacy: .public): \(error)")
                return (Config(), true)
            } catch let moveError {
                logger.error("Unreadable config could not be moved aside; not saving changes: \(moveError)")
                return (Config(), false)
            }
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save config: \(error)")
        }
    }
}
