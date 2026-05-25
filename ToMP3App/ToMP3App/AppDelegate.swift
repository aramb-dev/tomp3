import AppKit
import SwiftUI
import UserNotifications

// MARK: - App Entry Point

@main
struct ToMP3AppMain {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

  private var menuBarController: MenuBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hide from Dock — this is a menu bar only app
    NSApp.setActivationPolicy(.accessory)

    // Request notification permission
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

    menuBarController = MenuBarController()
  }
}
