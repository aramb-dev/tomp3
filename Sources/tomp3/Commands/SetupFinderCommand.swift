import ArgumentParser
import Foundation
import ToMP3Core

struct SetupFinderCommand: ParsableCommand {

  static var configuration = CommandConfiguration(
    commandName: "setup-finder",
    abstract: "Enable the tomp3 Finder extension for right-click conversion"
  )

  func run() throws {
    printHeader()

    // Already enabled?
    if FinderSetup.isEnabled() {
      print("  \(Term.green)\(Term.bold)✓ Finder extension is already enabled!\(Term.reset)")
      print("  Right-click any audio or video file in Finder → Convert to MP3.\n")
      return
    }

    // Guide
    print("  \(Term.bold)Set up the Finder Extension\(Term.reset)")
    print("  Adds a right-click menu to convert files directly from Finder.\n")
    print("  \(Term.cyan)Step 1.\(Term.reset)  System Settings will open to \(Term.bold)Extensions\(Term.reset).")
    print("  \(Term.cyan)Step 2.\(Term.reset)  Click \(Term.bold)Finder Extensions\(Term.reset) in the left sidebar.")
    print("  \(Term.cyan)Step 3.\(Term.reset)  Tick the checkbox next to \(Term.bold)tomp3\(Term.reset).")
    print("  \(Term.cyan)Step 4.\(Term.reset)  Come back and right-click any audio/video file in Finder!\n")
    print("  \(Term.yellow)→\(Term.reset) Opening System Settings…\n")

    // Open the settings pane
    let opener = Process()
    opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    opener.arguments = [FinderSetup.settingsURL.absoluteString]
    try opener.run()
    opener.waitUntilExit()

    // Poll for up to 60 seconds
    print("  Waiting for you to enable the extension ", terminator: "")
    fflush(stdout)
    for _ in 0..<60 {
      Thread.sleep(forTimeInterval: 1)
      if FinderSetup.isEnabled() {
        print("\n")
        print("  \(Term.green)\(Term.bold)✓ Done! Finder extension is now enabled.\(Term.reset)")
        print("  Right-click any audio or video file in Finder → Convert to MP3.\n")
        return
      }
      print(".", terminator: "")
      fflush(stdout)
    }

    // Timed out
    print("\n")
    print("  \(Term.yellow)⚠\(Term.reset)  Extension not detected yet.")
    print("  If you enabled it, try restarting Finder:")
    print("    killall Finder\n")
    print("  Or re-run \(Term.bold)tomp3 setup-finder\(Term.reset) to check again.\n")
  }
}
