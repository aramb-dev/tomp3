import AppKit
import SwiftUI
import ToMP3Core
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

  // MARK: - tomp3:// URL scheme (used by Finder extension)
  // tomp3://convert?preset=high&file=/path/to/a.mp3&file=/path/to/b.wav

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      guard
        url.scheme == "tomp3",
        url.host   == "convert",
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let queryItems = components.queryItems
      else { continue }

      let preset = queryItems
        .first(where: { $0.name == "preset" })
        .flatMap { Preset(rawValue: $0.value ?? "") } ?? .high

      let files = queryItems
        .filter { $0.name == "file" }
        .compactMap { $0.value }
        .map { URL(fileURLWithPath: $0) }

      guard !files.isEmpty else { continue }

      menuBarController?.convert(urls: files, preset: preset)
    }
  }
}
