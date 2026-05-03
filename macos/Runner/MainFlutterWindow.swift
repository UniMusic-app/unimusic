import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        // Full-size content so Flutter draws behind the titlebar area.
        self.styleMask.insert(.fullSizeContentView)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true

        setupToolbar()

        self.delegate = self

        // Prevent compact layout on macOS – sidebar should always be visible.
        self.minSize = NSSize(width: 700, height: 500)

        RegisterGeneratedPlugins(registry: flutterViewController)

        let registrar = flutterViewController.registrar(forPlugin: "AudioRoutingPlugin")
        AudioRoutingPlugin.register(with: registrar)

        super.awakeFromNib()
    }

    // Keep a standard-height invisible toolbar so the drag area covers
    // the full sidebar height and the traffic lights sit nicely positioned
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.showsBaselineSeparator = false
        self.toolbar = toolbar
        self.toolbarStyle = .unified
    }

    override func awakeAfter(using coder: NSCoder) -> Any? {
        let result = super.awakeAfter(using: coder)
        repositionTrafficLights()
        return result
    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        repositionTrafficLights()
    }

    private func repositionTrafficLights() {
        // In fullscreen the traffic light buttons are hidden and managed by
        // the system – repositioning them causes layout glitches, so bail out.
        guard !styleMask.contains(.fullScreen) else { return }

        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let xOffset: CGFloat = 20
        let yOffset: CGFloat = 20
        let spacing: CGFloat = 20

        for (index, buttonType) in buttons.enumerated() {
            guard let button = self.standardWindowButton(buttonType) else { continue }
            var origin = button.frame.origin
            origin.x = xOffset + CGFloat(index) * spacing
            // In flipped coordinates (titlebar counts from top), set from superview top.
            if let superview = button.superview {
                origin.y = superview.frame.height - button.frame.height - yOffset
            }
            button.setFrameOrigin(origin)
        }
    }
}

extension MainFlutterWindow: NSWindowDelegate {
    func windowWillEnterFullScreen(_ notification: Notification) {
        // Remove the toolbar entirely in fullscreen so it doesn't render as an
        // opaque black bar. In fullscreen, titlebarAppearsTransparent does not
        // keep the toolbar transparent the way it does in windowed mode.
        self.toolbar = nil
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        // Restore the toolbar when returning to windowed mode so the drag region
        // and traffic-light insets are re-established.
        setupToolbar()
    }
}
