import Foundation

// MARK: - Quality Preset

public enum Preset: String, CaseIterable, Sendable {
  case tiny     = "tiny"
  case small    = "small"
  case medium   = "medium"
  case standard = "standard"
  case high     = "high"

  /// Short human-readable label with spec (used in App UI and Finder extension menu)
  public var displayName: String {
    switch self {
    case .tiny:     return "Tiny (~15 kbps · voice only)"
    case .small:    return "Small (~27 kbps · podcasts)"
    case .medium:   return "Medium (~43 kbps · speech)"
    case .standard: return "Standard (~130 kbps · music)"
    case .high:     return "High (~190 kbps · best quality)"
    }
  }

  /// ffmpeg encoding arguments for this preset
  public var ffmpegArgs: [String] {
    switch self {
    case .tiny:     return ["-ac", "1", "-ar", "16000", "-q:a", "9"]
    case .small:    return ["-ac", "1", "-ar", "16000", "-q:a", "7"]
    case .medium:   return ["-ac", "1", "-ar", "22050", "-q:a", "5"]
    case .standard: return ["-ac", "1", "-ar", "44100", "-q:a", "3"]
    case .high:     return ["-ac", "2", "-ar", "44100", "-q:a", "2"]
    }
  }
}
