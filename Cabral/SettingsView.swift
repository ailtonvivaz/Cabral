import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(BrowserCatalog.self) private var catalog
    @FocusState private var focusedRule: UUID?
    @State private var isDefault = DefaultBrowser.isCurrent
    @State private var showDefaultHelp = false
    @State private var showTester = false
    @State private var testInput = ""

    var body: some View {
        @Bindable var store = store

        Form {
            if !isDefault {
                Section {
                    DefaultBrowserBanner(action: makeDefault)
                }
            }

            Section {
                if store.config.rules.isEmpty {
                    Text("No rules. Every link follows “Others”.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.config.rules.sorted { $0.domain < $1.domain }) { rule in
                    RuleRow(rule: rule, focus: $focusedRule, isMatch: test?.rule?.id == rule.id)
                }
            } header: {
                Text("Rules")
            } footer: {
                Text("Each rule also covers subdomains: company.com covers app.company.com.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    HStack(spacing: 10) {
                        ActionPicker(selection: $store.config.fallback)
                            .frame(width: 180, alignment: .trailing)
                        // Keeps the picker aligned with the rule rows' remove button.
                        Image(systemName: "minus.circle.fill").hidden()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Others")
                        if test?.isFallback == true { MatchBadge() }
                    }
                }
            } footer: {
                Text("Links that match no rule.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 420)
        .toolbar {
            ToolbarSpacer(.flexible)
            ToolbarItem(placement: .automatic) {
                Button("Test URL", systemImage: "testtube.2") { showTester.toggle() }
                    .help("Test where a URL goes")
                    .popover(isPresented: $showTester, arrowEdge: .bottom) {
                        TesterPopover(input: $testInput, outcome: test)
                    }
            }
            ToolbarItem(placement: .automatic) {
                Button("Add Rule", systemImage: "plus", action: addRule)
                    .help("Add rule")
            }
        }
        .onChange(of: showTester) { _, shown in
            if !shown { testInput = "" }
        }
        .alert("Set it manually", isPresented: $showDefaultHelp) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("System Settings › Desktop & Dock › Default web browser → Cabral.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isDefault = DefaultBrowser.isCurrent
        }
    }

    private var test: TestOutcome? {
        let input = testInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return nil }
        guard let url = URL(string: input.contains("://") ? input : "https://" + input), url.host() != nil else {
            return .invalid
        }
        let unwrapped = LinkUnwrapper.unwrap(url)
        let (rule, action) = Router.resolve(unwrapped, in: store.config)
        return .match(host: Domain.normalize(unwrapped.absoluteString), rule: rule, action: action)
    }

    private func addRule() {
        if let empty = store.config.rules.first(where: { $0.domain.isEmpty }) {
            focusedRule = empty.id
            return
        }
        let rule = Rule(domain: "", action: catalog.browsers.first.map { .browser($0.id) } ?? .ask)
        store.config.rules.append(rule)
        Task { focusedRule = rule.id }
    }

    private func makeDefault() {
        Task {
            let ok = await DefaultBrowser.makeCurrent()
            isDefault = DefaultBrowser.isCurrent
            showDefaultHelp = !ok && !isDefault
        }
    }
}

enum TestOutcome {
    case invalid
    case match(host: String, rule: Rule?, action: Action)

    var rule: Rule? {
        if case .match(_, let rule, _) = self { return rule }
        return nil
    }

    var isFallback: Bool {
        if case .match(_, nil, _) = self { return true }
        return false
    }
}

private struct DefaultBrowserBanner: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cabral isn’t the default browser")
                    .fontWeight(.medium)
                Text("Links open straight in the current browser, skipping your rules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Make Default", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}

private struct TesterPopover: View {
    @Binding var input: String
    let outcome: TestOutcome?
    @Environment(BrowserCatalog.self) private var catalog

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("URL", text: $input, prompt: Text("company.com/path"))
                .textFieldStyle(.roundedBorder)
            Group {
                switch outcome {
                case nil:
                    Text("Type a URL to see where it goes.")
                        .foregroundStyle(.secondary)
                case .invalid:
                    Label("Invalid URL", systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                case .match(_, let rule, let action):
                    HStack(spacing: 6) {
                        BrowserIcon(action: action, size: 16)
                        Text(catalog.name(of: action))
                            .fontWeight(.medium)
                        Text(verbatim: "·").foregroundStyle(.tertiary)
                        Text(rule.map { String(localized: "rule \($0.domain)") } ?? String(localized: "Others"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)
            .lineLimit(1)
        }
        .padding(14)
        .frame(width: 300)
    }
}
