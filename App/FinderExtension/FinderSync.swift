import Cocoa
import FinderSync

// MARK: - Finder Sync Extension
//
// This extension is sandboxed, so it cannot spawn processes (no ffmpeg).
// Instead it delegates conversion to the main ToMP3App via the tomp3:// URL scheme.

final class FinderSyncExtension: FIFinderSync {

  override init() {
    super.init()
    // Watch all mounted volumes so the right-click menu appears everywhere
    FIFinderSyncController.default().directoryURLs = [
      URL(fileURLWithPath: "/"),
      URL(fileURLWithPath: NSHomeDirectory()),
    ]
  }

  // MARK: - Context Menu

  override func menu(for menuKind: FIMenuKind) -> NSMenu {
    guard menuKind == .contextualMenuForItems else { return NSMenu() }

    let root = NSMenu(title: "")
    let item = NSMenuItem(title: "Convert to MP3", action: nil, keyEquivalent: "")
    item.image = NSImage(systemSymbolName: "waveform.badge.plus", accessibilityDescription: nil)

    let submenu = NSMenu(title: "Convert to MP3")

    // Presets in order from best to smallest
    let presets: [(label: String, raw: String)] = [
      ("High Quality (~190 kbps)",  "high"),
      ("Standard (~130 kbps)",      "standard"),
      ("Medium (~43 kbps)",         "medium"),
      ("Small (~27 kbps)",          "small"),
      ("Tiny (~15 kbps)",           "tiny"),
    ]

    for preset in presets {
      let sub = NSMenuItem(
        title: preset.label,
        action: #selector(convertWithPreset(_:)),
        keyEquivalent: ""
      )
      sub.representedObject = preset.raw
      sub.target = self
      submenu.addItem(sub)
    }

    item.submenu = submenu
    root.addItem(item)
    return root
  }

  // MARK: - Delegation via tomp3:// URL scheme

  @objc private func convertWithPreset(_ sender: NSMenuItem) {
    guard
      let preset = sender.representedObject as? String,
      let urls   = FIFinderSyncController.default().selectedItemURLs(),
      !urls.isEmpty
    else { return }

    // Build tomp3://convert?preset=high&file=/path/to/file1&file=/path/to/file2
    var components = URLComponents()
    components.scheme = "tomp3"
    components.host   = "convert"

    var items = [URLQueryItem(name: "preset", value: preset)]
    for url in urls {
      items.append(URLQueryItem(name: "file", value: url.path))
    }
    components.queryItems = items

    guard let deepLink = components.url else { return }

    // Open ToMP3App via the URL scheme — it handles the actual conversion
    NSWorkspace.shared.open(deepLink)
  }
}
