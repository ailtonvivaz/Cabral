import SwiftUI

struct PickerView: View {
    @Bindable var model: PickerModel
    let choose: (Int) -> Void

    private var width: CGFloat { max(300, CGFloat(model.browsers.count) * 82 + 26) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.host.isEmpty ? model.link.url.absoluteString : model.host)
                    .font(.headline)
                Text(model.link.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let sender = model.link.sender {
                    Text("opened by \(sender)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if model.browsers.isEmpty {
                Text("No browsers found.")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                        Button {
                            choose(index)
                        } label: {
                            VStack(spacing: 4) {
                                Image(nsImage: browser.icon)
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                Text(browser.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(verbatim: index < 9 ? "\(index + 1)" : " ")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 76)
                            .padding(.vertical, 8)
                            .background(index == model.selected ? Color.accentColor.opacity(0.18) : .clear, in: .rect(cornerRadius: 10))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .onHover { if $0 { model.selected = index } }
                    }
                }
            }

            if !model.host.isEmpty {
                Toggle("Always use for \(model.host)", isOn: $model.remember)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(width: width, alignment: .leading)
    }
}
