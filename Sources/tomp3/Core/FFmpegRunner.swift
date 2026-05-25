import Foundation

// MARK: - ffmpeg runner

struct FFmpegRunner {

  static func convert(_ job: ConversionJob) async -> ConversionResult {
    let inputSize = fileSize(job.inputURL)

    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = [
      "ffmpeg", "-i", job.inputURL.path,
      "-vn"
    ] + job.preset.ffmpegArgs + [
      "-codec:a", "libmp3lame",
      job.outputURL.path,
      "-y"
    ]
    p.standardError  = Pipe()   // suppress ffmpeg's verbose output
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

    let success = p.terminationStatus == 0 && FileManager.default.fileExists(atPath: job.outputURL.path)
    let outputSize = success ? fileSize(job.outputURL) : "-"

    let debugCmd = "ffmpeg -i \"\(job.inputURL.path)\" -vn \(job.preset.ffmpegArgs.joined(separator: " ")) -codec:a libmp3lame \"\(job.outputURL.path)\" -y"

    return ConversionResult(
      job: job, success: success,
      inputSize: inputSize, outputSize: outputSize,
      error: success ? nil : "Conversion failed.\nDebug: \(debugCmd)"
    )
  }

  // MARK: Batch

  /// Converts multiple jobs in parallel (up to `maxConcurrent` at once).
  static func convertBatch(
    _ jobs: [ConversionJob],
    maxConcurrent: Int = ProcessInfo.processInfo.activeProcessorCount,
    progress: @escaping (ConversionResult) -> Void
  ) async -> [ConversionResult] {
    var results: [ConversionResult] = []

    await withTaskGroup(of: ConversionResult.self) { group in
      var inFlight = 0
      var jobIter  = jobs.makeIterator()

      // Seed initial batch
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
}
