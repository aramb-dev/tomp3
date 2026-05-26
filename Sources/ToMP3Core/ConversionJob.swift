import Foundation

// MARK: - Conversion Job

public struct ConversionJob: Identifiable, Sendable {
  public let id: UUID
  public let inputURL: URL
  public let outputURL: URL
  public let preset: Preset

  /// - Parameters:
  ///   - input: Source audio/video file.
  ///   - outputDir: Directory to write the MP3. Defaults to the same folder as the input file.
  ///   - preset: Quality preset.
  public init(input: URL, outputDir: URL? = nil, preset: Preset) {
    self.id       = UUID()
    self.inputURL = input
    self.preset   = preset
    let dir  = outputDir ?? input.deletingLastPathComponent()
    let stem = input.deletingPathExtension().lastPathComponent
    self.outputURL = dir.appendingPathComponent("\(stem)_\(preset.rawValue).mp3")
  }
}

// MARK: - Conversion Result

public struct ConversionResult: Sendable {
  public let job: ConversionJob
  public let success: Bool
  public let inputSize: String
  public let outputSize: String
  public let error: String?

  public var displayName: String { job.inputURL.lastPathComponent }

  public init(
    job: ConversionJob,
    success: Bool,
    inputSize: String,
    outputSize: String,
    error: String?
  ) {
    self.job        = job
    self.success    = success
    self.inputSize  = inputSize
    self.outputSize = outputSize
    self.error      = error
  }
}
