import Testing

@testable import Cabral

struct DomainTests {
    @Test(arguments: [
        ("company.com", "company.com"),
        ("https://company.com", "company.com"),
        ("http://Sub.Company.COM:8080/path?q=1", "sub.company.com"),
        ("  company.com/x  \n", "company.com"),
        ("company.com.", "company.com"),
        ("", ""),
        ("   ", ""),
    ])
    func normalize(input: String, expected: String) {
        #expect(Domain.normalize(input) == expected)
    }

    @Test func matchesExactHost() {
        #expect(Domain.matches(host: "company.com", domain: "company.com"))
    }

    @Test func matchesSubdomain() {
        #expect(Domain.matches(host: "a.b.company.com", domain: "company.com"))
    }

    @Test func doesNotMatchSuffixWithoutDot() {
        #expect(!Domain.matches(host: "notcompany.com", domain: "company.com"))
    }

    @Test func emptyDomainNeverMatches() {
        #expect(!Domain.matches(host: "company.com", domain: ""))
        #expect(!Domain.matches(host: "", domain: ""))
    }
}
