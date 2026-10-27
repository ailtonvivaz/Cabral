import Foundation
import Testing

@testable import Cabral

struct LinkUnwrapperTests {
    private func wrap(_ target: String, in base: String, param: String = "url") -> URL {
        var components = URLComponents(string: base)!
        components.queryItems = [URLQueryItem(name: param, value: target), URLQueryItem(name: "data", value: "x")]
        return components.url!
    }

    @Test func unwrapsSafeLinks() {
        let url = wrap("https://example.com/doc?a=1", in: "https://nam02.safelinks.protection.outlook.com/")
        #expect(LinkUnwrapper.unwrap(url).absoluteString == "https://example.com/doc?a=1")
    }

    @Test func unwrapsTeamsOneCDN() {
        let url = wrap("https://example.com/", in: "https://teams.public.onecdn.static.microsoft/redirect")
        #expect(LinkUnwrapper.unwrap(url).absoluteString == "https://example.com/")
    }

    @Test func unwrapsNestedWrappers() {
        let inner = wrap("https://example.com/final", in: "https://www.google.com/url", param: "q")
        let outer = wrap(inner.absoluteString, in: "https://nam02.safelinks.protection.outlook.com/")
        #expect(LinkUnwrapper.unwrap(outer).absoluteString == "https://example.com/final")
    }

    @Test func unwrapsGoogleURLRedirect() {
        let url = wrap("https://example.com/", in: "https://www.google.com/url", param: "q")
        #expect(LinkUnwrapper.unwrap(url).absoluteString == "https://example.com/")
    }

    @Test func leavesGoogleSearchAlone() {
        let url = wrap("https://example.com/", in: "https://www.google.com/search", param: "q")
        #expect(LinkUnwrapper.unwrap(url) == url)
    }

    @Test func refusesNonHTTPTargets() {
        let url = wrap("javascript:alert(1)", in: "https://nam02.safelinks.protection.outlook.com/")
        #expect(LinkUnwrapper.unwrap(url) == url)
    }

    @Test func leavesPlainLinksAlone() {
        let url = URL(string: "https://example.com/?url=https://other.com")!
        #expect(LinkUnwrapper.unwrap(url) == url)
    }
}
