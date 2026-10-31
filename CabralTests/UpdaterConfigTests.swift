import Foundation
import Testing

/// The README's privacy section describes these Sparkle settings; changing one changes that promise.
struct UpdaterConfigTests {
    private let info = Bundle(identifier: "app.vivaz.Cabral")?.infoDictionary ?? [:]

    @Test func feedIsTheLatestGitHubRelease() {
        #expect(
            info["SUFeedURL"] as? String
                == "https://github.com/ailtonvivaz/Cabral/releases/latest/download/appcast.xml")
    }

    @Test func sendsNoSystemProfile() {
        #expect(info["SUEnableSystemProfiling"] as? Bool == false)
    }

    /// Sparkle must ask before the first automatic check.
    @Test func automaticChecksNeedConsent() {
        #expect(info["SUEnableAutomaticChecks"] == nil)
        #expect(info["SUAutomaticallyUpdate"] == nil)
    }

    @Test func feedAndUpdatesMustBeSigned() {
        #expect(info["SURequireSignedFeed"] as? Bool == true)
        #expect(info["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
        #expect(info["SUPublicEDKey"] is String)
    }
}
