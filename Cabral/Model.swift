import Foundation

nonisolated enum Action: Hashable, Sendable {
    case browser(String)
    case ask
}

/// On disk an action is a plain string: "ask" or a browser bundle id.
nonisolated extension Action: Codable {
    private enum LegacyKey: String, CodingKey { case ask, browser, _0 }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            guard !value.isEmpty else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Empty action"))
            }
            self = value == "ask" ? .ask : .browser(value)
            return
        }
        // Pre-0.1.0 builds wrote the synthesized enum shape: {"ask":{}} or {"browser":{"_0":"<id>"}}.
        let legacy = try decoder.container(keyedBy: LegacyKey.self)
        if legacy.contains(.browser) {
            self = .browser(try legacy.nestedContainer(keyedBy: LegacyKey.self, forKey: .browser).decode(String.self, forKey: ._0))
        } else if legacy.contains(.ask) {
            self = .ask
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown action"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .ask: try container.encode("ask")
        case .browser(let id): try container.encode(id)
        }
    }
}

nonisolated struct Rule: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var domain: String
    var action: Action
}

/// Decoders live in extensions so the memberwise initializers survive.
nonisolated extension Rule {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Hand-edited configs may leave out the id; it only matters for SwiftUI identity.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        domain = try container.decode(String.self, forKey: .domain)
        action = try container.decode(Action.self, forKey: .action)
    }
}

nonisolated struct Config: Codable, Sendable {
    /// Format version of config.json, bumped only on breaking changes.
    var version = 1
    var rules: [Rule] = []
    var fallback: Action = .ask
}

nonisolated extension Config {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? defaults.version
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? defaults.rules
        fallback = try container.decodeIfPresent(Action.self, forKey: .fallback) ?? defaults.fallback
    }
}

nonisolated enum Domain {
    /// "https://Sub.Company.com:8080/x" → "sub.company.com". Returns "" when no host can be parsed.
    static func normalize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let host = URL(string: withScheme)?.host(percentEncoded: false) else { return "" }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    /// Component-based: "company.com" matches "a.company.com" but not "notcompany.com".
    static func matches(host: String, domain: String) -> Bool {
        !domain.isEmpty && (host == domain || host.hasSuffix("." + domain))
    }
}

nonisolated enum LinkUnwrapper {
    /// Redirect pages that carry the real destination in a query parameter
    /// (Teams/Outlook Safe Links, Google result redirects).
    private static let wrappers: [(domain: String, path: String?, param: String)] = [
        ("teams.public.onecdn.static.microsoft", nil, "url"),
        ("statics.teams.cdn.office.net", nil, "url"),
        ("safelinks.protection.outlook.com", nil, "url"),
        ("google.com", "/url", "q"),
    ]

    static func unwrap(_ url: URL) -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        let host = Domain.normalize(url.absoluteString)
        for wrapper in wrappers
        where Domain.matches(host: host, domain: wrapper.domain) && (wrapper.path == nil || components.path == wrapper.path) {
            if let value = components.queryItems?.first(where: { $0.name == wrapper.param })?.value,
                let target = URL(string: value), ["http", "https"].contains(target.scheme?.lowercased())
            {
                return unwrap(target)
            }
        }
        return url
    }
}
