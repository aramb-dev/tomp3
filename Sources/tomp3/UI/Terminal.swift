import Foundation

// MARK: - ANSI terminal helpers

enum Term {
  static let reset  = "\u{1B}[0m"
  static let bold   = "\u{1B}[1m"
  static let dim    = "\u{1B}[2m"
  static let red    = "\u{1B}[0;31m"
  static let green  = "\u{1B}[0;32m"
  static let yellow = "\u{1B}[1;33m"
  static let cyan   = "\u{1B}[0;36m"
  static let blue   = "\u{1B}[0;34m"

  /// Returns plain string if stdout is not a tty (e.g. pipe / script)
  static func c(_ code: String, _ text: String) -> String {
    isatty(STDOUT_FILENO) != 0 ? "\(code)\(text)\(reset)" : text
  }
}

// MARK: - Output helpers

func printOk(_ msg: String)   { print("  \(Term.green)✓\(Term.reset) \(msg)") }
func printInfo(_ msg: String) { print("  \(Term.dim)\(msg)\(Term.reset)") }
func printWarn(_ msg: String) { print("  \(Term.yellow)⚠\(Term.reset) \(msg)") }
func printError(_ msg: String){ fputs("\n  \(Term.red)✗ \(msg)\(Term.reset)\n\n", stderr) }

func printHeader() {
  print("")
  print("  \(Term.bold)\(Term.cyan)┌──────────────────────────────────────────┐\(Term.reset)")
  print("  \(Term.bold)\(Term.cyan)│           tomp3 converter  v\(AppMeta.version)             │\(Term.reset)")
  print("  \(Term.bold)\(Term.cyan)└──────────────────────────────────────────┘\(Term.reset)")
  print("")
}

// MARK: - Spinner

final class Spinner {
  private let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
  private let message: String
  private var thread: Thread?
  private var running = false

  init(message: String) {
    self.message = message
  }

  func start() {
    guard isatty(STDOUT_FILENO) != 0 else { return }
    running = true
    let t = Thread {
      var i = 0
      while self.running {
        let frame = self.frames[i % self.frames.count]
        print("\r  \(Term.cyan)\(frame)\(Term.reset)  \(self.message)…", terminator: "")
        fflush(stdout)
        i += 1
        Thread.sleep(forTimeInterval: 0.1)
      }
    }
    t.start()
    thread = t
  }

  func stop() {
    running = false
    thread = nil
    if isatty(STDOUT_FILENO) != 0 {
      print("\r" + String(repeating: " ", count: 60) + "\r", terminator: "")
      fflush(stdout)
    }
  }
}

// MARK: - Interactive prompt helpers

func prompt(_ label: String) -> String {
  print("  \(Term.dim)▸\(Term.reset) ", terminator: "")
  fflush(stdout)
  return readLine(strippingNewline: true) ?? ""
}

func promptPreset() -> Preset? {
  print("  \(Term.bold)Choose a quality preset:\(Term.reset)\n")
  for (i, p) in Preset.allCases.enumerated() {
    print("  \(Term.bold)\(Term.cyan)\(i + 1)\(Term.reset)  \(p.menuEntry)")
  }
  print("")
  let raw = prompt("1–\(Preset.allCases.count)")
  guard let idx = Int(raw), idx >= 1, idx <= Preset.allCases.count else { return nil }
  return Preset.allCases[idx - 1]
}

// MARK: - File size helper

func fileSize(_ url: URL) -> String {
  let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
  let kb = Double(bytes) / 1024
  if kb < 1024 { return String(format: "%.0f KB", kb) }
  return String(format: "%.1f MB", kb / 1024)
}
