import ArgumentParser
import ToMP3Core

// MARK: - ArgumentParser conformance

extension Preset: ExpressibleByArgument {}

// MARK: - CLI display

extension Preset {
  /// Colored menu entry for the interactive preset picker.
  var menuEntry: String {
    switch self {
    case .tiny:
      return "\(Term.bold)\(Term.cyan)tiny\(Term.reset)      \(Term.dim)~15 kbps · 16 kHz · mono   — ultra compact, voice only\(Term.reset)"
    case .small:
      return "\(Term.bold)\(Term.cyan)small\(Term.reset)     \(Term.dim)~27 kbps · 16 kHz · mono   — lectures, podcasts\(Term.reset)"
    case .medium:
      return "\(Term.bold)\(Term.cyan)medium\(Term.reset)    \(Term.dim)~43 kbps · 22 kHz · mono   — clear speech, balanced\(Term.reset)"
    case .standard:
      return "\(Term.bold)\(Term.cyan)standard\(Term.reset)  \(Term.dim)~130 kbps · 44 kHz · mono  — music, general use\(Term.reset)"
    case .high:
      return "\(Term.bold)\(Term.cyan)high\(Term.reset)      \(Term.dim)~190 kbps · 44 kHz · stereo — best quality\(Term.reset)"
    }
  }
}
