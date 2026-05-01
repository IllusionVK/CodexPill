import AppKit

@MainActor
struct PanelWindowFactory {
    private let appIconSource: AppIconSource

    init(appIconSource: AppIconSource) {
        self.appIconSource = appIconSource
    }

    func makePanel(title: String, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.documentIconButton)?.image = appIconSource.appIconImage()
        return panel
    }
}
