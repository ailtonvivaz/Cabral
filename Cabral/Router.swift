import Foundation

nonisolated enum Router {
    /// Most specific rule wins. Two matching domains are suffixes of the same host,
    /// so the longer one is always the more specific.
    static func resolve(_ url: URL, in config: Config) -> (rule: Rule?, action: Action) {
        let host = Domain.normalize(url.absoluteString)
        let rule = config.rules
            .filter { Domain.matches(host: host, domain: $0.domain) }
            .max { $0.domain.count < $1.domain.count }
        return (rule, rule?.action ?? config.fallback)
    }
}
