import Foundation

// MARK: - FFmpeg Runner

public struct FFmpegRunner {

  // MARK: - ffmpeg path resolution

  /// Resolves the ffmpeg binary. Checks known Homebrew locations first,
  /// then falls back to a PATH lookup via /usr/bin/env.
  public static var ffmpegPath: String? {
    let candidates = [
      "/opt/homebrew/bin/ffmpeg",   // Apple Silicon Homebrew
      "/usr/local/bin/ffmpeg",      // Intel Homebrew
      "/usr/bin/ffmpeg",            // system (unlikely but possible)
    ]
    if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
      return found
    }
    // Last resort: ask the shell (works in CLI context, may fail in sandboxed apps)
    return resolveViaWhich()
  }

  // MARK: - Single conversion

  public static func convert(_ job: ConversionJob) async -> ConversionResult {
    let inputSize = fileSize(job.inputURL)

    guard let ffmpeg = ffmpegPath else {
      return ConversionResult(
        job: job, success: false,
        inputSize: inputSize, outputSize: "-",
        error: "ffmpeg not found. Install via: brew install ffmpeg"
      )
    }

    let p = Process()
    p.executableURL = URL(fileURLWithPath: ffmpeg)
    p.arguments = [
      "-i", job.inputURL.path,
      "-vn",
    ] + job.preset.ffmpegArgs + [
      "-codec:a", "libmp3lame",
      job.outputURL.path,
      "-y",
    ]
    p.standardError  = Pipe()
    p.standardOutput = Pipe()

    do {
      try p.run()
    } catch {
      return ConversionResult(
        job: job, success: false,
        inputSize: inputSize, outputSize: "-",
        error: "Failed to launch ffmpeg: \(error.localizedDescription)"
      )
    }

    await withCheckedContinuation { cont in
      p.terminationHandler = { _ in cont.resume() }
    }

    let success = p.terminationStatus == 0
      && FileManager.default.fileExists(atPath: job.outputURL.path)
    let outputSize = success ? fileSize(job.outputURL) : "-"

    return ConversionResult(
      job: job, success: success,
      inputSize: inputSize, outputSize: outputSize,
      error: success ? nil : "ffmpeg exited with code \(p.terminationStatus)"
    )
  }

  // MARK: - Batch conversion

  /// Converts multiple jobs concurrently (up to `maxConcurrent` at once).
  public static func convertBatch(
    _ jobs: [ConversionJob],
    maxConcurrent: Int = ProcessInfo.processInfo.activeProcessorCount,
    progress: @escaping @Sendable (ConversionResult) -> Void
  ) async -> [ConversionResult] {
    var results: [ConversionResult] = []

    await withTaskGroup(of: ConversionResult.self) { group in
      var inFlight = 0
      var jobIter  = jobs.makeIterator()

      while inFlight < maxConcurrent, let job = jobIter.next() {
        group.addTask { await convert(job) }
        inFlight += 1
      }

      for await result in group {
        progress(result)
        results.append(result)
        if let next = jobIter.next() {
          group.addTask { await convert(next) }
        }
      }
    }

    return results
  }

  // MARK: - Helpers

  private static func fileSize(_ url: URL) -> String {
    guard let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
      return "-"
    }
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }

  private static func resolveViaWhich() -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    p.arguments = ["ffmpeg"]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError  = Pipe()
    try? p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return out?.isEmpty == false ? out : nil
  }
}
