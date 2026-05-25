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

      print("""
        \n  \(Term.yellow)Update available:\(Term.reset) v\(remote)  \(Term.dim)(you have v\(AppMeta.version))\(Term.reset)
          \(Term.dim)→ \(AppMeta.releaseURL)\(Term.reset)\n
        """)
    } catch {
      // Offline or timeout — skip silently
    }
  }
}
