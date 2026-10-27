import Foundation
import Testing

@testable import Cabral

struct RouterTests {
    private let url = URL(string: "https://app.team.company.com/page")!

    @Test func mostSpecificRuleWins() {
        let config = Config(rules: [
            Rule(domain: "company.com", action: .browser("com.example.a")),
            Rule(domain: "team.company.com", action: .browser("com.example.b")),
        ])
        let result = Router.resolve(url, in: config)
        #expect(result.rule?.domain == "team.company.com")
        #expect(result.action == .browser("com.example.b"))
    }

    @Test func fallbackWhenNoRuleMatches() {
        let config = Config(rules: [Rule(domain: "other.com", action: .ask)], fallback: .browser("com.example.default"))
        let result = Router.resolve(url, in: config)
        #expect(result.rule == nil)
        #expect(result.action == .browser("com.example.default"))
    }

    @Test func askRuleOverridesBrowserFallback() {
        let config = Config(rules: [Rule(domain: "company.com", action: .ask)], fallback: .browser("com.example.default"))
        #expect(Router.resolve(url, in: config).action == .ask)
    }

    @Test func browserRuleOverridesAskFallback() {
        let config = Config(rules: [Rule(domain: "company.com", action: .browser("com.example.a"))], fallback: .ask)
        #expect(Router.resolve(url, in: config).action == .browser("com.example.a"))
    }
}
