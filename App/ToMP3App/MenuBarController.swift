import AppKit
import SwiftUI
import ToMP3Core

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
      button.action = #selector(handleClick(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

  // MARK: - Public API (called by AppDelegate for Finder extension URL scheme)

  func convert(urls: [URL], preset: Preset) {
    manager.convert(urls: urls, preset: preset)
  }

  // MARK: - Click handling

  @objc private func handleClick(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp {
      showContextMenu(sender)
    } else {
      togglePopover(sender)
    }
  }

  private func togglePopover(_ sender: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(sender)
    } else {
      popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  // MARK: - Right-click context menu

  private func showContextMenu(_ sender: NSStatusBarButton) {
    let menu = NSMenu()

    if let version = updater.availableVersion {
      let updateItem = NSMenuItem(
        title: "Update to v\(version)…",
        action: #selector(installUpdate),
        keyEquivalent: ""
      )
      updateItem.target = self
      menu.addItem(updateItem)
      menu.addItem(.separator())
    } else {
      let checkItem = NSMenuItem(
        title: "Check for Updates…",
        action: #selector(checkForUpdates),
        keyEquivalent: ""
      )
      checkItem.target = self
      menu.addItem(checkItem)
      menu.addItem(.separator())
    }

    let quitItem = NSMenuItem(
      title: "Quit tomp3",
      action: #selector(NSApp.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quitItem)

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    // Reset so left-click still opens popover next time
    DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
  }

  @objc private func checkForUpdates() {
    updater.checkInBackground()
  }

  @objc private func installUpdate() {
    guard let version = updater.availableVersion else { return }
    updater.install(version: version)
  }
}

