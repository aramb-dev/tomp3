import Foundation

// MARK: - FFmpeg Runner (shared, no CLI dependencies)

struct FFmpegRunner {

  // MARK: - ffmpeg path resolution

  static var ffmpegPath: String? {
    let candidates = [
      "/opt/homebrew/bin/ffmpeg",   // Apple Silicon Homebrew
      "/usr/local/bin/ffmpeg",      // Intel Homebrew
      "/usr/bin/ffmpeg",
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
  }

  // MARK: - Single conversion

  static func convert(_ job: ConversionJob) async -> ConversionResult {
    guard let ffmpeg = ffmpegPath else {
      return ConversionResult(
        job: job, success: false,
        inputSize: "-", outputSize: "-",
        error: "ffmpeg not found. Install it via: brew install ffmpeg"
      )
    }

    let inputSize = fileSize(job.inputURL)

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
      error: success ? nil : "ffmpeg exited with status \(p.terminationStatus)"
    )
  }

  // MARK: - Batch conversion

  static func convertBatch(
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
    guard let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "-" }
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }
}
