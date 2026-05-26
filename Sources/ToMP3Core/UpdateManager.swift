import Foundation

// MARK: - Shared update logic (used by CLI and menu bar app)

public struct UpdateManager {

  // MARK: - Check

  /// Fetches the remote version and returns it if it's newer than the current build.
  public static func fetchAvailableUpdate() async -> String? {
    guard let url = URL(string: AppMeta.versionURL) else { return nil }
    guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
    let remote = String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !remote.isEmpty, isNewer(remote: remote, than: AppMeta.version) else { return nil }
    return remote
  }

  // MARK: - Download + install

  /// Downloads the pkg for `version` to a temp file, runs `installer` via osascript
  /// (prompts for password), then calls `completion` with success/failure.
  public static func install(
    version: String,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    let urlString = String(format: AppMeta.pkgURL, version, version)
    guard let url = URL(string: urlString) else {
      throw UpdateError.badURL(urlString)
    }

    let dest = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("tomp3-\(version)-macos.pkg")

    // Download with progress
    let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
    let total = response.expectedContentLength
    var data  = Data()
    var received: Int64 = 0

    for try await byte in asyncBytes {
      data.append(byte)
      received += 1
      if total > 0 { progress(Double(received) / Double(total)) }
    }
    try data.write(to: dest)

    // Install via osascript (handles privilege escalation)
    let escaped = dest.path.replacingOccurrences(of: "'", with: "'\\''")
    let script  = "do shell script \"installer -pkg '\(escaped)' -target /\" with administrator privileges"
    let osa     = Process()
    osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    osa.arguments     = ["-e", script]
    let errPipe = Pipe()
    osa.standardError = errPipe

    try osa.run()
    osa.waitUntilExit()

    try? FileManager.default.removeItem(at: dest)

    if osa.terminationStatus != 0 {
      let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
      if msg.contains("User cancelled") || msg.contains("-128") {
        throw UpdateError.cancelled
      }
      throw UpdateError.installFailed(msg)
    }
  }

  // MARK: - Version comparison

  public static func isNewer(remote: String, than current: String) -> Bool {
    let rv = versionTuple(remote)
    let cv = versionTuple(current)
    for i in 0..<max(rv.count, cv.count) {
      let r = i < rv.count ? rv[i] : 0
      let c = i < cv.count ? cv[i] : 0
      if r != c { return r > c }
    }
    return false
  }

  private static func versionTuple(_ v: String) -> [Int] {
    v.split(separator: ".").compactMap { Int($0) }
  }
}

// MARK: - Errors

public enum UpdateError: Error, LocalizedError {
  case badURL(String)
  case cancelled
  case installFailed(String)

  public var errorDescription: String? {
    switch self {
    case .badURL(let u):       return "Invalid download URL: \(u)"
    case .cancelled:           return "Update cancelled."
    case .installFailed(let m): return "Installation failed: \(m)"
    }
  }
}
