import ArgumentParser
import Foundation

// MARK: - Update Command

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct UpdateCommand: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Check for and install the latest version of tomp3."
  )

  @Flag(name: [.short, .long], help: "Only check — don't download or install.")
  var checkOnly: Bool = false

  // ─── Run ──────────────────────────────────────────────────────────────────

  func run() async throws {
    print("")
    print("  \(Term.bold)Checking for updates…\(Term.reset)")

    guard let remoteVersion = await fetchRemoteVersion() else {
      printWarn("Could not reach update server. Check your connection.")
      throw ExitCode.failure
    }

    let current = AppMeta.version

    if !isNewer(remote: remoteVersion, than: current) {
      printOk("Already up to date  \(Term.dim)(v\(current))\(Term.reset)")
      print("")
      return
    }

    print("")
    print("  \(Term.yellow)\(Term.bold)Update available:\(Term.reset)  \(Term.dim)v\(current)\(Term.reset)  →  \(Term.green)\(Term.bold)v\(remoteVersion)\(Term.reset)")
    print("")

    // Show what's new for the remote version
    if let notes = await fetchWhatsNew(for: remoteVersion) {
      print("  \(Term.bold)What's new in v\(remoteVersion):\(Term.reset)")
      for line in notes {
        print("  \(Term.cyan)·\(Term.reset) \(line)")
      }
      print("")
    }

    if checkOnly {
      print("  \(Term.dim)Run \(Term.reset)tomp3 update\(Term.dim) to install.\(Term.reset)\n")
      return
    }

    // ── Download pkg ──────────────────────────────────────────────────────────
    let pkgName = "tomp3-\(remoteVersion)-macos.pkg"
    let downloadURL = "https://github.com/aramb-dev/tomp3/releases/download/v\(remoteVersion)/\(pkgName)"
    let destURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(pkgName)

    guard let url = URL(string: downloadURL) else {
      printError("Invalid download URL: \(downloadURL)")
      throw ExitCode.failure
    }

    print("  \(Term.dim)Downloading \(pkgName)…\(Term.reset)")
    print("")

    do {
      try await downloadWithProgress(from: url, to: destURL)
    } catch {
      printError("Download failed: \(error.localizedDescription)")
      printInfo("Manual download: \(AppMeta.releaseURL)")
      throw ExitCode.failure
    }

    print("")
    printOk("Downloaded to \(Term.dim)\(destURL.path)\(Term.reset)")

    // ── Install silently via osascript (handles privilege escalation) ────────
    print("  \(Term.bold)Installing…\(Term.reset)  \(Term.dim)(you may be asked for your password)\(Term.reset)")
    print("")

    let script = """
      do shell script "installer -pkg \(destURL.path.shellEscaped) -target /" with administrator privileges
      """
    let osa = Process()
    osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    osa.arguments = ["-e", script]
    let errPipe = Pipe()
    osa.standardError = errPipe

    do {
      try osa.run()
      osa.waitUntilExit()
    } catch {
      printError("Could not launch installer: \(error.localizedDescription)")
      throw ExitCode.failure
    }

    if osa.terminationStatus != 0 {
      let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
      if errMsg.contains("User cancelled") || errMsg.contains("-128") {
        print("  \(Term.yellow)Installation cancelled.\(Term.reset)\n")
        return
      }
      printError("Installation failed.\n  \(errMsg)")
      printInfo("You can install manually:\n    open \"\(destURL.path)\"")
      throw ExitCode.failure
    }

    // Clean up temp pkg
    try? FileManager.default.removeItem(at: destURL)

    print("  \(Term.green)\(Term.bold)✓  tomp3 updated to v\(remoteVersion)!\(Term.reset)")
    print("  \(Term.dim)Open a new terminal window for changes to take effect.\(Term.reset)\n")
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private func fetchRemoteVersion() async -> String? {
    guard let url = URL(string: AppMeta.versionURL) else { return nil }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let v = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return v.isEmpty ? nil : v
    } catch {
      return nil
    }
  }

  /// Fetches CHANGELOG.md and extracts bullet points for the given version section.
  private func fetchWhatsNew(for version: String) async -> [String]? {
    guard let url = URL(string: AppMeta.changelogURL) else { return nil }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let text = String(data: data, encoding: .utf8) else { return nil }

      var inSection = false
      var lines: [String] = []

      for line in text.components(separatedBy: "\n") {
        if line.hasPrefix("## v\(version)") {
          inSection = true
          continue
        }
        if inSection {
          if line.hasPrefix("## ") { break }  // next section — stop
          let trimmed = line
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "^- ", with: "", options: .regularExpression)
          if !trimmed.isEmpty { lines.append(trimmed) }
        }
      }
      return lines.isEmpty ? nil : lines
    } catch {
      return nil
    }
  }

  /// Returns true if `remote` is semantically greater than `current`.
  private func isNewer(remote: String, than current: String) -> Bool {
    let rv = versionTuple(remote)
    let cv = versionTuple(current)
    // Compare element by element
    for i in 0..<max(rv.count, cv.count) {
      let r = i < rv.count ? rv[i] : 0
      let c = i < cv.count ? cv[i] : 0
      if r != c { return r > c }
    }
    return false
  }

  private func versionTuple(_ v: String) -> [Int] {
    v.split(separator: ".").compactMap { Int($0) }
  }

  // ── Download with live progress bar ──────────────────────────────────────────

  private func downloadWithProgress(from url: URL, to dest: URL) async throws {
    let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
    let total = response.expectedContentLength  // -1 if unknown

    var data = Data()
    var received: Int64 = 0
    let barWidth = 30

    for try await byte in asyncBytes {
      data.append(byte)
      received += 1

      // Update progress every 32 KB
      if received % 32_768 == 0 || received == total {
        if total > 0 {
          let pct = Double(received) / Double(total)
          let filled = Int(pct * Double(barWidth))
          let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barWidth - filled)
          let mb = String(format: "%.1f / %.1f MB", Double(received) / 1_048_576, Double(total) / 1_048_576)
          print("\r  \(Term.cyan)\(bar)\(Term.reset)  \(mb)   ", terminator: "")
          fflush(stdout)
        } else {
          let mb = String(format: "%.1f MB", Double(received) / 1_048_576)
          print("\r  \(Term.cyan)↓\(Term.reset)  \(mb)   ", terminator: "")
          fflush(stdout)
        }
      }
    }

    // Clear progress line
    print("\r" + String(repeating: " ", count: 60) + "\r", terminator: "")
    fflush(stdout)

    try data.write(to: dest)
  }
}

// MARK: - Shell escaping helper

private extension String {
  /// Wraps the string in single quotes, escaping any embedded single quotes.
  var shellEscaped: String {
    "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
