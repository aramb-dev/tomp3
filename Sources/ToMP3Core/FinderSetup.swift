import Foundation

// MARK: - Finder Extension setup helpers (shared by CLI + App)

public enum FinderSetup {

  public static let bundleID  = "dev.aramb.tomp3app.findersync"
  public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!

  /// Whether the Finder Sync extension is currently enabled.
  /// Uses `pluginkit` — works in non-sandboxed contexts (CLI).
  /// Returns `false` rather than throwing if the check fails.
  public static func isEnabled() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
    task.arguments = ["-m", "-A", "-D", "-i", bundleID]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError  = Pipe()   // suppress noise
    do {
      try task.run()
      task.waitUntilExit()
    } catch {
      return false
    }
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    // pluginkit prefixes enabled plugins with "+"
    return output.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
  }
}
