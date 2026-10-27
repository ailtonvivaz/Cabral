import SwiftUI

struct RuleRow: View {
    let rule: Rule
    var focus: FocusState<UUID?>.Binding
    let isMatch: Bool

    @Environment(Store.self) private var store
    @Environment(BrowserCatalog.self) private var catalog
    @State private var draft = ""
    @State private var error: String?
    @State private var isHovering = false

    private var index: Int? { store.config.rules.firstIndex { $0.id == rule.id } }

    private var action: Binding<Action> {
        Binding(
            get: { rule.action },
            set: { newValue in if let index { store.config.rules[index].action = newValue } }
        )
    }

    private var isMissingBrowser: Bool {
        if case .browser(let id) = rule.action { return catalog.browser(id) == nil }
        return false
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Domain", text: $draft, prompt: Text("company.com"))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                    .focused(focus, equals: rule.id)
                    .onSubmit(commit)
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            if isMatch { MatchBadge() }
            Spacer()
            if isMissingBrowser {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("Browser not installed")
            }
            ActionPicker(selection: action)
                .frame(width: 180, alignment: .trailing)
            Button("Remove", systemImage: "minus.circle.fill", role: .destructive, action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .opacity(isHovering ? 1 : 0)
                .help("Remove rule")
        }
        .onHover { isHovering = $0 }
        .onAppear { draft = rule.domain }
        .onChange(of: focus.wrappedValue) { old, new in
            if old == rule.id, new != rule.id { commit() }
        }
        .contextMenu {
            Button("Remove", role: .destructive, action: remove)
        }
    }

    private func commit() {
        guard let index else { return }
        let domain = Domain.normalize(draft)
        if domain.isEmpty {
            if rule.domain.isEmpty { remove() } else { draft = rule.domain; error = nil }
            return
        }
        if store.config.rules.contains(where: { $0.domain == domain && $0.id != rule.id }) {
            error = String(localized: "A rule for \(domain) already exists")
            return
        }
        error = nil
        draft = domain
        store.config.rules[index].domain = domain
    }

    private func remove() {
        store.config.rules.removeAll { $0.id == rule.id }
    }
}

struct ActionPicker: View {
    @Binding var selection: Action
    @Environment(BrowserCatalog.self) private var catalog

    var body: some View {
        Picker("Target", selection: $selection) {
            ForEach(catalog.browsers) { browser in
                Label {
                    Text(browser.name)
                } icon: {
                    Image(nsImage: browser.smallIcon)
                }
                .tag(Action.browser(browser.id))
            }
            if case .browser(let id) = selection, catalog.browser(id) == nil {
                Text("\(id) (not installed)").tag(selection)
            }
            Divider()
            Label("Ask", systemImage: "questionmark.circle")
                .tag(Action.ask)
        }
        .labelsHidden()
    }
}

struct BrowserIcon: View {
    let action: Action
    var size: CGFloat = 32
    @Environment(BrowserCatalog.self) private var catalog

    var body: some View {
        Group {
            if case .browser(let id) = action, let browser = catalog.browser(id) {
                Image(nsImage: browser.icon)
                    .resizable()
            } else {
                Image(systemName: action == .ask ? "questionmark.circle.fill" : "app.dashed")
                    .resizable()
                    .padding(size * 0.1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MatchBadge: View {
    var body: some View {
        Text("matched")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.18), in: .capsule)
    }
}

extension BrowserCatalog {
    func name(of action: Action) -> String {
        switch action {
        case .ask: String(localized: "Ask")
        case .browser(let id): browser(id)?.name ?? id
        }
    }
}
