import ArgumentParser
import Foundation

// MARK: - Convert Command

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct ConvertCommand: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "convert",
    abstract: "Convert audio files to MP3.",
    discussion: """
      Converts one or more audio files to MP3 using ffmpeg.
      When run without arguments, launches an interactive prompt.

      Examples:
        tomp3 interview.wav
        tomp3 *.wav --preset tiny --output ./compressed/
        tomp3 --batch ./recordings/ --preset small --open
        tomp3 convert lecture.m4a --preset medium --quiet
      """
  )

  // ─── Arguments & Options ────────────────────────────────────────────────────

  @Flag(
    name: .customShort("v"),
    help: "Show the version and exit."
  )
  var showVersion: Bool = false

  @Argument(
    help: ArgumentHelp(
      "Input audio file(s) to convert.",
      valueName: "file"
    )
  )
  var inputs: [String] = []

  @Option(
    name: [.short, .long],
    help: "Quality preset: tiny | small | medium | standard | high"
  )
  var preset: Preset?

  @Option(
    name: [.short, .long],
    help: "Output directory. Defaults to same folder as each input file."
  )
  var output: String?

  @Option(
    name: [.short, .long],
    help: "Max parallel jobs for batch mode (default: CPU count)."
  )
  var jobs: Int?

  @Flag(
    name: [.long],
    help: "Scan a directory for all audio files (use --inputs as the directory)."
  )
  var batch: Bool = false

  @Flag(
    name: [.long],
    help: "Open the output folder in Finder when done."
  )
  var open: Bool = false

  @Flag(
    name: [.short, .long],
    help: "Suppress all output except errors (useful for scripting)."
  )
  var quiet: Bool = false

  @Flag(
    name: [.long],
    help: "Skip the update check."
  )
  var noUpdateCheck: Bool = false

  // ─── Run ────────────────────────────────────────────────────────────────────

  func run() async throws {
    if showVersion {
      print(AppMeta.version)
      return
    }

    if !quiet { printHeader() }

    // Update check (async, non-blocking feel — runs before deps check)
    if !noUpdateCheck {
      await UpdateChecker.checkForUpdate()
    }

    // Ensure ffmpeg is available
    guard DependencyChecker.ensureFFmpeg() else {
      throw ExitCode.failure
    }

    // Resolve jobs
    let jobList = try resolveJobs()
    guard !jobList.isEmpty else {
      printError("No valid audio files to convert.")
      throw ExitCode.failure
    }

    let maxJobs = jobs ?? ProcessInfo.processInfo.activeProcessorCount

    // ── Single file: show spinner ──────────────────────────────────────────────
    if jobList.count == 1 {
      let job = jobList[0]
      if !quiet {
        printInfo("Input : \(job.inputURL.lastPathComponent)  (\(fileSize(job.inputURL)))")
        printInfo("Output: \(job.outputURL.lastPathComponent)")
        print("")
      }

      let spinner = quiet ? nil : Spinner(message: "Converting")
      spinner?.start()
      try? await Task.sleep(nanoseconds: 50_000_000) // let spinner paint first frame

      let result = await FFmpegRunner.convert(job)
      spinner?.stop()

      printResult(result)

    // ── Batch: show live counter ───────────────────────────────────────────────
    } else {
      if !quiet {
        print("  \(Term.bold)Batch:\(Term.reset) \(jobList.count) file(s) · up to \(maxJobs) parallel job(s)\n")
      }

      var completed = 0
      let total = jobList.count

      let results = await FFmpegRunner.convertBatch(jobList, maxConcurrent: maxJobs) { result in
        completed += 1
        if !quiet {
          let status = result.success ? "\(Term.green)✓\(Term.reset)" : "\(Term.red)✗\(Term.reset)"
          print("  \(status)  [\(completed)/\(total)]  \(result.job.outputURL.lastPathComponent)")
        }
      }

      if !quiet { printBatchSummary(results) }
    }

    // Open Finder
    if open, let outputDir = resolveOutputDir() {
      Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [outputDir.path])
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  private func resolveJobs() throws -> [ConversionJob] {
    var resolvedFiles: [URL] = []

    // ── Batch mode: scan directory ─────────────────────────────────────────────
    if batch {
      let dir = inputs.first.map { URL(fileURLWithPath: $0) }
             ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

      resolvedFiles = audioFiles(in: dir)
      if resolvedFiles.isEmpty {
        printError("No audio files found in: \(dir.path)")
        throw ExitCode.failure
      }

    // ── File list or interactive ───────────────────────────────────────────────
    } else if inputs.isEmpty {
      // Interactive: prompt for file path
      print("  \(Term.bold)Paste the file path (or drag from Finder):\(Term.reset)")
      let raw = prompt("path")
      let cleaned = cleanPath(raw)
      let url = URL(fileURLWithPath: cleaned)
      guard FileManager.default.fileExists(atPath: url.path) else {
        printError("File not found:\n    \(cleaned)")
        throw ExitCode.failure
      }
      resolvedFiles = [url]
    } else {
      resolvedFiles = try inputs.map { p -> URL in
        let url = URL(fileURLWithPath: p)
        guard FileManager.default.fileExists(atPath: url.path) else {
          throw ValidationError("File not found: \(p)")
        }
        return url
      }
    }

    // Resolve preset (interactive if not supplied)
    let chosenPreset: Preset
    if let p = preset {
      chosenPreset = p
    } else {
      print("")
      guard let p = promptPreset() else {
        printError("Invalid preset choice.")
        throw ExitCode.failure
      }
      chosenPreset = p
      print("")
    }

    // Build output dir
    let outDir = output.map { URL(fileURLWithPath: $0) }

    if let outDir, !FileManager.default.fileExists(atPath: outDir.path) {
      try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    return resolvedFiles.map { ConversionJob(input: $0, outputDir: outDir, preset: chosenPreset) }
  }

  private func resolveOutputDir() -> URL? {
    if let o = output { return URL(fileURLWithPath: o) }
    // Fall back to first output file's directory
    return nil // caller will use Finder-reveal on output file instead
  }

  private func printResult(_ result: ConversionResult) {
    if quiet {
      if !result.success {
        if let err = result.error { fputs(err + "\n", stderr) }
      } else {
        print(result.job.outputURL.path)
      }
      return
    }

    if result.success {
      print("  \(Term.green)\(Term.bold)✓  Done!\(Term.reset)\n")
      let inputName  = result.job.inputURL.lastPathComponent
      let outputName = result.job.outputURL.lastPathComponent
      print(String(format: "  \(Term.dim)Input : \(Term.reset)%-8s  %@", result.inputSize, inputName))
      print(String(format: "  \(Term.dim)Output: \(Term.reset)%-8s  %@", result.outputSize, outputName))
      print("")
      print("  \(Term.dim)Saved to:\(Term.reset)")
      print("  \(Term.cyan)\(result.job.outputURL.path)\(Term.reset)\n")
    } else {
      printError(result.error ?? "Conversion failed.")
    }
  }

  private func printBatchSummary(_ results: [ConversionResult]) {
    let ok    = results.filter(\.success).count
    let fail  = results.count - ok
    let saved = results.compactMap { $0.success ? $0.job.outputURL.path : nil }

    print("")
    print("  \(Term.bold)Summary:\(Term.reset) \(Term.green)\(ok) succeeded\(Term.reset)", terminator: "")
    if fail > 0 { print("  \(Term.red)\(fail) failed\(Term.reset)", terminator: "") }
    print("")

    if let first = saved.first {
      let dir = URL(fileURLWithPath: first).deletingLastPathComponent().path
      print("  \(Term.dim)Saved to:\(Term.reset) \(Term.cyan)\(dir)\(Term.reset)")
    }
    print("")
  }

  // ── Utilities ────────────────────────────────────────────────────────────────

  private func cleanPath(_ raw: String) -> String {
    var s = raw
    s = s.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("'") && s.hasSuffix("'") { s = String(s.dropFirst().dropLast()) }
    if s.hasPrefix("\"") && s.hasSuffix("\"") { s = String(s.dropFirst().dropLast()) }
    // Unescape any shell-escaped character (e.g. "\ ", "\(", "\)") → the bare char
    s = s.replacingOccurrences(of: "\\\\(.)", with: "$1", options: .regularExpression)
    return s
  }

  private var audioExtensions: Set<String> {
    return [
      "mp3","m4a","wav","aac","flac","ogg","opus","wma","aiff","aif","webm","mp4","mkv","mov"
    ]
  }

  private func audioFiles(in dir: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: dir,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return enumerator.compactMap { $0 as? URL }.filter { url in
      audioExtensions.contains(url.pathExtension.lowercased())
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
}
