import AppKit
import SwiftUI

// MARK: - Menu Bar Controller

@MainActor
final class MenuBarController {

  private var statusItem: NSStatusItem
  private var popover: NSPopover
  private let manager = ConversionManager()
  private let updater = AppUpdateChecker()

  init() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    popover    = NSPopover()

    configure()
    updater.checkInBackground()
  }

  // MARK: - Setup

  private func configure() {
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "waveform.badge.plus",
        accessibilityDescription: "tomp3"
      )
      button.action = #selector(togglePopover(_:))
      button.target = self
    }

    popover.contentSize  = NSSize(width: 340, height: 520)
    popover.behavior     = .transient
    popover.animates     = true
    popover.contentViewController = NSHostingController(
      rootView: StatusItemView()
        .environmentObject(manager)
        .environmentObject(updater)
    )
  }

  // MARK: - Popover toggle

  @objc private func togglePopover(_ sender: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(sender)
    } else if let button = statusItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}
