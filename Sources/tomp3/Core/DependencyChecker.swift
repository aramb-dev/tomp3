import Foundation

// MARK: - Dependency checks

struct DependencyChecker {

  /// Checks for ffmpeg, auto-installs via Homebrew if missing.
  /// Returns false and prints a user-facing error if install fails.
  static func ensureFFmpeg() -> Bool {
    guard which("ffmpeg") == nil else { return true }

    printWarn("ffmpeg not found.")

    guard which("brew") != nil else {
      printError("Homebrew is required to install ffmpeg.\nInstall it from https://brew.sh then re-run tomp3.")
      return false
    }

    print("  \(Term.yellow)Installing ffmpeg via Homebrew…\(Term.reset)\n")
    let result = shell("brew", "install", "ffmpeg")
    if result == 0 {
      printOk("ffmpeg installed")
      return true
    } else {
      printError("ffmpeg install failed. Run manually:\n\n    brew install ffmpeg")
      return false
    }
  }

  // MARK: Helpers

  @discardableResult
  private static func shell(_ cmd: String, _ args: String...) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = [cmd] + args
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
  }

  private static func which(_ cmd: String) -> String? {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    p.arguments = [cmd]
    p.standardOutput = pipe
    p.standardError = Pipe()
    try? p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
