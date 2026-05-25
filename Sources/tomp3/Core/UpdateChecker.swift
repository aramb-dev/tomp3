import Foundation

// MARK: - Self-update checker

struct UpdateChecker {

  /// Checks the remote VERSION file and prints an update notice if a newer version exists.
  /// Silently ignores network failures (offline-safe).
  static func checkForUpdate() async {
    guard let url = URL(string: AppMeta.versionURL) else { return }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let remote = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      guard !remote.isEmpty, remote != AppMeta.version else { return }

      print("")
      print("  \(Term.yellow)Update available:\(Term.reset) \(Term.dim)v\(AppMeta.version)\(Term.reset) → \(Term.bold)v\(remote)\(Term.reset)")
      print("  \(Term.dim)Run \(Term.reset)\(Term.bold)tomp3 update\(Term.reset)\(Term.dim) to install, or download at:\(Term.reset)")
      print("  \(Term.cyan)\(AppMeta.releaseURL)\(Term.reset)")
      print("")
    } catch {
      // Offline or timeout — skip silently
    }
  }
}
