import Foundation
import ToMP3Core
import UserNotifications

// MARK: - Conversion Manager

@MainActor
final class ConversionManager: ObservableObject {

  @Published var activeJobs: [ActiveJob] = []
  @Published var recentResults: [ConversionResult] = []

  // MARK: - Active job wrapper

  struct ActiveJob: Identifiable {
    let id = UUID()
    let fileName: String
    let preset: Preset
    var isComplete = false
    var success    = false
  }

  // MARK: - Clear

  func clearRecent() {
    activeJobs.removeAll { $0.isComplete }
    recentResults.removeAll()
  }

  // MARK: - Convert

  func convert(urls: [URL], preset: Preset) {
    let jobs = urls.map { ConversionJob(input: $0, preset: preset) }
    let tracked = jobs.map { ActiveJob(fileName: $0.inputURL.lastPathComponent, preset: preset) }
    activeJobs.append(contentsOf: tracked)

    Task {
      let results = await FFmpegRunner.convertBatch(jobs) { [weak self] result in
        Task { @MainActor [weak self] in
          self?.handleResult(result, tracked: tracked)
        }
      }
      notifyCompletion(results: results)
    }
  }

  // MARK: - Result handling

  private func handleResult(_ result: ConversionResult, tracked: [ActiveJob]) {
    // Mark the matching tracked job done
    if let idx = activeJobs.firstIndex(where: { $0.fileName == result.job.inputURL.lastPathComponent }) {
      activeJobs[idx].isComplete = true
      activeJobs[idx].success    = result.success
    }

    recentResults.insert(result, at: 0)
    if recentResults.count > 10 { recentResults.removeLast() }

    // Clean up completed jobs after a short delay
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      activeJobs.removeAll { $0.isComplete }
    }
  }

  // MARK: - Notification

  private func notifyCompletion(results: [ConversionResult]) {
    let successCount = results.filter(\.success).count
    let failCount    = results.count - successCount

    let content = UNMutableNotificationContent()
    content.title = "tomp3"

    if failCount == 0 {
      content.body = "\(successCount) file\(successCount == 1 ? "" : "s") converted successfully"
    } else {
      content.body = "\(successCount) converted, \(failCount) failed"
    }
    content.sound = .default

    let req = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(req)
  }
}
