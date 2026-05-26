import Cocoa
import ToMP3Core
import FinderSync
import UserNotifications

// MARK: - Finder Sync Extension

final class FinderSyncExtension: FIFinderSync {

  override init() {
    super.init()
    // Watch all mounted volumes so the extension is active everywhere
    FIFinderSyncController.default().directoryURLs = [
      URL(fileURLWithPath: "/"),
      URL(fileURLWithPath: NSHomeDirectory()),
    ]

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  // MARK: - Context Menu

  override func menu(for menuKind: FIMenuKind) -> NSMenu {
    guard menuKind == .contextualMenuForItems else { return NSMenu() }

    let root = NSMenu(title: "")
    let item = NSMenuItem(title: "Convert to MP3", action: nil, keyEquivalent: "")
    item.image = NSImage(systemSymbolName: "waveform.badge.plus", accessibilityDescription: nil)

    let submenu = NSMenu(title: "Convert to MP3")
    for preset in Preset.allCases {
      let sub = NSMenuItem(
        title: preset.displayName,
        action: #selector(convertWithPreset(_:)),
        keyEquivalent: ""
      )
      sub.representedObject = preset.rawValue
      sub.target = self
      submenu.addItem(sub)
    }

    item.submenu = submenu
    root.addItem(item)
    return root
  }

  // MARK: - Conversion

  @objc private func convertWithPreset(_ sender: NSMenuItem) {
    guard
      let rawValue = sender.representedObject as? String,
      let preset   = Preset(rawValue: rawValue),
      let urls     = FIFinderSyncController.default().selectedItemURLs(),
      !urls.isEmpty
    else { return }

    let jobs = urls.map { ConversionJob(input: $0, preset: preset) }

    Task {
      let results = await FFmpegRunner.convertBatch(jobs) { _ in }
      await notifyCompletion(results: results)
    }
  }

  // MARK: - Notification

  @MainActor
  private func notifyCompletion(results: [ConversionResult]) {
    let successCount = results.filter(\.success).count
    let failCount    = results.count - successCount

    let content = UNMutableNotificationContent()
    content.title = "tomp3"
    content.body  = failCount == 0
      ? "\(successCount) file\(successCount == 1 ? "" : "s") converted to MP3"
      : "\(successCount) converted, \(failCount) failed"
    content.sound = .default

    let req = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(req)
  }
}
