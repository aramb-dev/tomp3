import SwiftUI
import ToMP3Core
import UniformTypeIdentifiers

// MARK: - Status Item Popover View

struct StatusItemView: View {

  @EnvironmentObject private var manager: ConversionManager
  @EnvironmentObject private var updater: AppUpdateChecker
  @State private var selectedPreset: Preset = .high
  @State private var isTargeted = false
  @State private var justDropped = false

  /// Persisted: user confirmed extension is set up (or dismissed the banner)
  @AppStorage("finderSetupDone") private var finderSetupDone = false

  // Accepted media UTTypes
  private let acceptedTypes: [UTType] = [
    .audio, .movie, .mpeg4Movie, .quickTimeMovie,
    UTType("public.mp3")!, UTType("public.mpeg-4-audio")!,
    UTType("com.apple.m4a-audio")!, UTType("public.aiff-audio")!,
    UTType("com.microsoft.waveform-audio")!,
  ]

  private var runningCount: Int { manager.activeJobs.filter { !$0.isComplete }.count }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      presetPicker
      Divider()
      dropZone
      if !finderSetupDone {
        Divider()
        finderSetupBanner
      }
      Divider()
      queueSection
      Spacer(minLength: 0)
      footer
    }
    .frame(width: 340)
    .background(.regularMaterial)
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      Image(systemName: "waveform")
        .font(.title2)
        .foregroundStyle(Color.accentColor)
      Text("tomp3")
        .font(.headline)
      Spacer()
      Button("Choose Files…") { pickFiles() }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  // MARK: - Preset Picker

  private var presetPicker: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Quality")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)

      Picker("Quality", selection: $selectedPreset) {
        ForEach(Preset.allCases, id: \.self) { preset in
          Text(preset.rawValue.capitalized).tag(preset)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .padding(.horizontal, 14)
    }
    .padding(.vertical, 10)
  }

  // MARK: - Drop Zone

  private var dropZone: some View {
    RoundedRectangle(cornerRadius: 10)
      .strokeBorder(
        dropBorderColor,
        style: StrokeStyle(lineWidth: 2, dash: [6])
      )
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(dropFillColor)
      )
      .overlay {
        VStack(spacing: 6) {
          Image(systemName: justDropped ? "checkmark.circle.fill" : "arrow.down.circle")
            .font(.largeTitle)
            .foregroundStyle(isTargeted || justDropped ? Color.accentColor : .secondary)
            .animation(.easeInOut(duration: 0.15), value: justDropped)
          Text(justDropped ? "Added to queue" : "Drop audio or video files here")
            .font(.callout)
            .foregroundStyle(justDropped ? Color.accentColor : .secondary)
            .animation(.easeInOut(duration: 0.15), value: justDropped)
        }
      }
      .frame(height: 100)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
        handleDrop(providers)
      }
  }

  private var dropBorderColor: Color {
    justDropped ? Color.accentColor : (isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
  }

  private var dropFillColor: Color {
    justDropped ? Color.accentColor.opacity(0.06) : (isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
  }

  // MARK: - Finder Setup Banner

  private var finderSetupBanner: some View {
    VStack(alignment: .leading, spacing: 10) {

      // Header row
      HStack(alignment: .top) {
        Image(systemName: "puzzlepiece.extension.fill")
          .foregroundStyle(Color.accentColor)
          .font(.callout)
        VStack(alignment: .leading, spacing: 2) {
          Text("Enable Finder Extension")
            .font(.caption)
            .fontWeight(.semibold)
          Text("Right-click any audio or video file in Finder to convert.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          finderSetupDone = true
        } label: {
          Image(systemName: "xmark")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      // Steps
      VStack(alignment: .leading, spacing: 5) {
        finderStep(number: "1", text: "Click **Open Settings** below")
        finderStep(number: "2", text: "Select **Finder Extensions** in the sidebar")
        finderStep(number: "3", text: "Tick the checkbox next to **tomp3**")
      }

      // Action buttons
      HStack(spacing: 8) {
        Button {
          NSWorkspace.shared.open(FinderSetup.settingsURL)
        } label: {
          HStack(spacing: 4) {
            Text("Open Settings")
            Image(systemName: "arrow.up.right.square")
              .font(.caption2)
          }
          .font(.caption)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

        Button("Done, it's set up  ✓") {
          finderSetupDone = true
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(Color.accentColor)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color.accentColor.opacity(0.05))
  }

  private func finderStep(number: String, text: LocalizedStringKey) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Text(number)
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .frame(width: 16, height: 16)
        .background(Color.accentColor, in: Circle())
      Text(text)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Queue Section

  private var queueSection: some View {
    VStack(alignment: .leading, spacing: 0) {

      // Section header row
      HStack {
        Text(runningCount > 0 ? "Converting…" : "Queue")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)
        Spacer()
        if runningCount > 0 {
          Text("\(runningCount) running")
            .font(.caption2)
            .foregroundStyle(.secondary)
        } else if !manager.activeJobs.isEmpty || !manager.recentResults.isEmpty {
          Button("Clear") {
            manager.clearRecent()
          }
          .buttonStyle(.plain)
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 14)
      .padding(.top, 10)
      .padding(.bottom, 6)

      // Overall progress bar — visible while any job is running
      if runningCount > 0 {
        let total     = manager.activeJobs.count
        let done      = manager.activeJobs.filter(\.isComplete).count
        let progress  = total > 0 ? Double(done) / Double(total) : 0

        VStack(spacing: 3) {
          ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(Color.accentColor)
          HStack {
            Text("\(done) of \(total) done")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
          }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
      }

      // Job rows
      let allRows = manager.activeJobs + manager.recentResults.prefix(5).map { r in
        // map recent results back into the same row shape
        ConversionManager.ActiveJob(
          fileName: r.displayName,
          preset: r.job.preset,
          isComplete: true,
          success: r.success
        )
      }

      if allRows.isEmpty {
        Text("No conversions yet — drop files above")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 16)
      } else {
        ForEach(allRows) { job in
          jobRow(job)
        }
      }

      Spacer(minLength: 6)
    }
    .frame(minHeight: 100)
  }

  @ViewBuilder
  private func jobRow(_ job: ConversionManager.ActiveJob) -> some View {
    HStack(spacing: 8) {
      Group {
        if job.isComplete {
          Image(systemName: job.success ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(job.success ? .green : .red)
        } else {
          ProgressView()
            .controlSize(.mini)
            .frame(width: 14, height: 14)
        }
      }
      .frame(width: 16)

      Text(job.fileName)
        .font(.caption)
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer()

      Text(job.preset.rawValue.capitalized)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 4)
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: 0) {
      // Update banner
      if let version = updater.availableVersion {
        Divider()
        if updater.isInstalling {
          HStack(spacing: 8) {
            ProgressView(value: updater.installProgress)
              .progressViewStyle(.linear)
            Text("\(Int(updater.installProgress * 100))%")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
        } else {
          Button {
            updater.install(version: version)
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.down.circle.fill")
              Text("Update to v\(version)")
                .fontWeight(.medium)
              Spacer()
              Text("Free")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .font(.callout)
          }
          .buttonStyle(.plain)
          .foregroundStyle(Color.accentColor)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(Color.accentColor.opacity(0.07))

          if let err = updater.installError {
            Text(err)
              .font(.caption2)
              .foregroundStyle(.red)
              .padding(.horizontal, 14)
              .padding(.bottom, 6)
          }
        }
      }

      Divider()
      HStack {
        Text("tomp3  \(AppMeta.version)")
          .font(.caption2)
          .foregroundStyle(.tertiary)
        Spacer()
        Button("Quit") { NSApp.terminate(nil) }
          .buttonStyle(.plain)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
    }
  }

  // MARK: - Actions

  private func pickFiles() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories    = false
    panel.allowedContentTypes     = acceptedTypes
    panel.prompt                  = "Convert"
    panel.message                 = "Select audio or video files to convert to MP3"

    guard panel.runModal() == .OK else { return }
    manager.convert(urls: panel.urls, preset: selectedPreset)
    flashDropZone()
  }

  private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
    var urls: [URL] = []
    let group = DispatchGroup()

    for provider in providers {
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, _ in
        if let url { urls.append(url) }
        group.leave()
      }
    }

    group.notify(queue: .main) {
      if !urls.isEmpty {
        manager.convert(urls: urls, preset: selectedPreset)
        flashDropZone()
      }
    }
    return true
  }

  private func flashDropZone() {
    justDropped = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      justDropped = false
    }
  }
}
