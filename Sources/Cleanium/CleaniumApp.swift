import SwiftUI
import AppKit

/// Menu bar presence via NSStatusItem + NSPopover instead of MenuBarExtra:
/// MenuBarExtra's .window style draws an opaque backing that public API cannot
/// reliably clear, while a native NSPopover is the translucent material itself.
@MainActor
final class StatusBarController: NSObject, NSApplicationDelegate {
    let state = AppState()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover.contentSize = NSSize(width: 460, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView().environmentObject(state))

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "internaldrive",
                                     accessibilityDescription: "Cleanium")
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

@main
struct CleaniumApp: App {
    @NSApplicationDelegateAdaptor(StatusBarController.self) private var statusBar

    var body: some Scene {
        Settings {
            SettingsView().environmentObject(statusBar.state)
        }
    }
}
