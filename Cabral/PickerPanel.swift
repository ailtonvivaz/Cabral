import AppKit
import SwiftUI

struct PickerChoice {
    let browser: Browser
    let remember: Bool
}

@Observable
final class PickerModel {
    let link: LinkHandler.Link
    let host: String
    let browsers: [Browser]
    var selected = 0
    var remember = false

    init(link: LinkHandler.Link, host: String, browsers: [Browser]) {
        self.link = link
        self.host = host
        self.browsers = browsers
    }
}

/// Borderless, non-activating panel: becomes key (receives keyboard) without
/// stealing activation from the app that opened the link.
final class PickerPanel: NSPanel {
    private let model: PickerModel
    private let onFinish: (PickerChoice?) -> Void
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var finished = false

    init(link: LinkHandler.Link, host: String, browsers: [Browser], onFinish: @escaping (PickerChoice?) -> Void) {
        model = PickerModel(link: link, host: host, browsers: browsers)
        self.onFinish = onFinish
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        // The window server derives the shadow from a square outline the glass doesn't
        // fill, leaving dark corners. The glass edge already separates it from the desktop.
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Glass as the window's own content view: shaped by cornerRadius, so the
        // transparent corners of the borderless panel stay clear.
        let hosting = NSHostingView(rootView: PickerView(model: model) { [weak self] index in self?.choose(index) })
        let glass = NSGlassEffectView()
        glass.cornerRadius = 20
        glass.contentView = hosting
        contentView = glass
        setContentSize(hosting.fittingSize)
    }

    override var canBecomeKey: Bool { true }

    func show() {
        positionNearMouse()
        makeKeyAndOrderFront(nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
        }
        // Clicks in other apps dismiss. Losing key status alone does not, so an
        // alert for another link can't silently discard this one.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.finish(nil)
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:  // Esc
            finish(nil)
        case 36, 76:  // Return, Enter
            choose(model.selected)
        case 123:  // ←
            model.selected = max(0, model.selected - 1)
        case 124:  // →
            model.selected = min(model.browsers.count - 1, model.selected + 1)
        default:
            guard let number = event.charactersIgnoringModifiers.flatMap(Int.init), (1...9).contains(number) else { return false }
            choose(number - 1)
        }
        return true
    }

    private func choose(_ index: Int) {
        guard model.browsers.indices.contains(index) else { return }
        finish(PickerChoice(browser: model.browsers[index], remember: model.remember))
    }

    private func finish(_ choice: PickerChoice?) {
        guard !finished else { return }
        finished = true
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        orderOut(nil)
        onFinish(choice)
    }

    /// Below the cursor, clamped inside the visible frame of the cursor's screen.
    private func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return center() }
        let x = min(max(mouse.x - frame.width / 2, visible.minX + 8), visible.maxX - frame.width - 8)
        let y = min(max(mouse.y - frame.height - 16, visible.minY + 8), visible.maxY - frame.height - 8)
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
