import Foundation
import Testing

@testable import Cabral

struct ConfigCodingTests {
    private func decode(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    @Test func roundTripsNewFormat() throws {
        let config = Config(
            rules: [
                Rule(domain: "company.com", action: .browser("com.example.a")),
                Rule(domain: "other.com", action: .ask),
            ], fallback: .browser("com.example.b"))
        let data = try JSONEncoder().encode(config)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["version"] as? Int == 1)
        #expect(object["fallback"] as? String == "com.example.b")
        let rules = try #require(object["rules"] as? [[String: Any]])
        #expect(rules.map { $0["action"] as? String } == ["com.example.a", "ask"])

        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded.rules == config.rules)
        #expect(decoded.fallback == config.fallback)
    }

    @Test func decodesLegacyFormat() throws {
        let config = try decode(
            """
            {"fallback":{"ask":{}},"rules":[{"action":{"browser":{"_0":"com.example.a"}},"domain":"company.com","id":"6F1C3A52-7E1B-4C1E-9F57-0D6B7C1D2E3F"}]}
            """)
        #expect(config.version == 1)
        #expect(config.fallback == .ask)
        #expect(config.rules.first?.action == .browser("com.example.a"))
        #expect(config.rules.first?.id.uuidString == "6F1C3A52-7E1B-4C1E-9F57-0D6B7C1D2E3F")
    }

    @Test func missingKeysUseDefaults() throws {
        let empty = try decode("{}")
        #expect(empty.version == 1)
        #expect(empty.rules.isEmpty)
        #expect(empty.fallback == .ask)

        let noID = try decode(#"{"rules":[{"domain":"company.com","action":"ask"}]}"#)
        #expect(noID.rules.first?.domain == "company.com")
    }

    @Test func ignoresUnknownKeys() throws {
        let config = try decode(
            #"{"version":1,"future":true,"fallback":"com.example.a","rules":[{"domain":"x.com","action":"ask","note":"hi"}]}"#)
        #expect(config.fallback == .browser("com.example.a"))
        #expect(config.rules.count == 1)
    }

    @Test func rejectsEmptyAction() {
        #expect(throws: DecodingError.self) { try decode(#"{"fallback":""}"#) }
    }

    @MainActor
    @Test func corruptFileIsMovedAside() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CabralTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "config.json")
        try Data("not json".utf8).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        #expect(store.config.rules.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("config.corrupt-") && $0.hasSuffix(".json") }
        #expect(backups.count == 1)
        let backup = try #require(backups.first)
        #expect(try String(contentsOf: directory.appending(path: backup), encoding: .utf8) == "not json")
    }

    @MainActor
    @Test func storeSavesNewFormat() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CabralTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "config.json")

        let store = Store(fileURL: fileURL)
        store.setAction(.browser("com.example.a"), forDomain: "company.com")
        #expect(Store(fileURL: fileURL).config.rules.first?.action == .browser("com.example.a"))

        // Read-back alone would also accept the legacy shape, so check the bytes on disk.
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        #expect(object["version"] as? Int == 1)
        let rules = try #require(object["rules"] as? [[String: Any]])
        #expect(rules.first?["action"] as? String == "com.example.a")
    }
}
