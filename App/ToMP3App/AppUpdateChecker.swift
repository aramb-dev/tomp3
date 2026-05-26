import Foundation
import ToMP3Core

// MARK: - Update state for the menu bar app

@MainActor
final class AppUpdateChecker: ObservableObject {
  @Published var availableVersion: String? = nil
  @Published var isInstalling   = false
  @Published var installProgress: Double = 0
  @Published var installError: String? = nil

  func checkInBackground() {
    Task {
      availableVersion = await UpdateManager.fetchAvailableUpdate()
    }
  }

  func install(version: String) {
    isInstalling   = true
    installError   = nil
    installProgress = 0

    Task {
      do {
        try await UpdateManager.install(version: version) { [weak self] pct in
          Task { @MainActor [weak self] in
            self?.installProgress = pct
          }
        }
        // Success — postinstall script will relaunch the app automatically
        availableVersion = nil
        isInstalling     = false
      } catch UpdateError.cancelled {
        isInstalling = false
      } catch {
        installError = error.localizedDescription
        isInstalling = false
      }
    }
  }
}
