import Foundation

// MARK: - Conversion Job

struct ConversionJob: Identifiable {
  let id = UUID()
  let inputURL: URL
  let outputURL: URL
  let preset: Preset

  init(input: URL, preset: Preset) {
    self.inputURL = input
    self.preset = preset
    let dir  = input.deletingLastPathComponent()
    let stem = input.deletingPathExtension().lastPathComponent
    self.outputURL = dir.appendingPathComponent("\(stem)_\(preset.rawValue).mp3")
  }
}

// MARK: - Conversion Result

struct ConversionResult {
  let job: ConversionJob
  let success: Bool
  let inputSize: String
  let outputSize: String
  let error: String?

  var displayName: String { job.inputURL.lastPathComponent }
}
