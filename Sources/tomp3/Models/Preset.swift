import ArgumentParser
import Foundation

// MARK: - Quality Preset

enum Preset: String, CaseIterable, ExpressibleByArgument, CustomStringConvertible {
  case tiny     = "tiny"
  case small    = "small"
  case medium   = "medium"
  case standard = "standard"
  case high     = "high"

  var description: String { rawValue }

  /// Human-readable summary for the interactive menu
  var menuEntry: String {
    switch self {
    case .tiny:     return "\(Term.bold)\(Term.cyan)tiny\(Term.reset)      \(Term.dim)~15 kbps · 16 kHz · mono   — ultra compact, voice only\(Term.reset)"
    case .small:    return "\(Term.bold)\(Term.cyan)small\(Term.reset)     \(Term.dim)~27 kbps · 16 kHz · mono   — lectures, podcasts\(Term.reset)"
    case .medium:   return "\(Term.bold)\(Term.cyan)medium\(Term.reset)    \(Term.dim)~43 kbps · 22 kHz · mono   — clear speech, balanced\(Term.reset)"
    case .standard: return "\(Term.bold)\(Term.cyan)standard\(Term.reset)  \(Term.dim)~130 kbps · 44 kHz · mono  — music, general use\(Term.reset)"
    case .high:     return "\(Term.bold)\(Term.cyan)high\(Term.reset)      \(Term.dim)~190 kbps · 44 kHz · stereo — best quality\(Term.reset)"
    }
  }

  /// ffmpeg arguments for this preset
  var ffmpegArgs: [String] {
    switch self {
    case .tiny:     return ["-ac", "1", "-ar", "16000", "-q:a", "9"]
    case .small:    return ["-ac", "1", "-ar", "16000", "-q:a", "7"]
    case .medium:   return ["-ac", "1", "-ar", "22050", "-q:a", "5"]
    case .standard: return ["-ac", "1", "-ar", "44100", "-q:a", "3"]
    case .high:     return ["-ac", "2", "-ar", "44100", "-q:a", "2"]
    }
  }
}

// MARK: - Conversion Job

struct ConversionJob {
  let inputURL:  URL
  let outputURL: URL
  let preset:    Preset

  init(input: URL, outputDir: URL?, preset: Preset) {
    self.inputURL = input
    let dir = outputDir ?? input.deletingLastPathComponent()
    let stem = input.deletingPathExtension().lastPathComponent
    self.outputURL = dir.appendingPathComponent("\(stem)_\(preset.rawValue).mp3")
    self.preset = preset
  }
}

// MARK: - Conversion Result

struct ConversionResult {
  let job:       ConversionJob
  let success:   Bool
  let inputSize: String
  let outputSize: String
  let error:     String?
}
