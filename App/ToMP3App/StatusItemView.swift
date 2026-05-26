import SwiftUI
import ToMP3Core
import UniformTypeIdentifiers

// MARK: - Status Item Popover View

struct StatusItemView: View {

  @EnvironmentObject private var manager: ConversionManager
  @State private var selectedPreset: Preset = .high
  @State private var isTargeted = false

  // Accepted media UTTypes
  private let acceptedTypes: [UTType] = [
    .audio, .movie, .mpeg4Movie, .quickTimeMovie,
    UTType("public.mp3")!, UTType("public.mpeg-4-audio")!,
    UTType("com.apple.m4a-audio")!, UTType("public.aiff-audio")!,
    UTType("com.microsoft.waveform-audio")!,
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      presetPicker
      Divider()
      dropZone
      if !manager.activeJobs.isEmpty { activeJobsList }
      if !manager.recentResults.isEmpty { recentList }
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
        .foregroundStyle(.accent)
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
    Picker("Quality", selection: $selectedPreset) {
      ForEach(Preset.allCases, id: \.self) { preset in
        Text(preset.rawValue.capitalized).tag(preset)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }

  // MARK: - Drop Zone

  private var dropZone: some View {
    RoundedRectangle(cornerRadius: 10)
      .strokeBorder(
        isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
        style: StrokeStyle(lineWidth: 2, dash: [6])
      )
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
      )
      .overlay {
        VStack(spacing: 6) {
          Image(systemName: "arrow.down.circle")
            .font(.largeTitle)
            .foregroundStyle(isTargeted ? .accent : .secondary)
          Text("Drop audio or video files here")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      .frame(height: 100)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
        handleDrop(providers)
      }
  }

  // MARK: - Active Jobs

  private var activeJobsList: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Converting…")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)

      ForEach(manager.activeJobs) { job in
        HStack(spacing: 8) {
          if job.isComplete {
            Image(systemName: job.success ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundStyle(job.success ? .green : .red)
          } else {
            ProgressView().controlSize(.mini)
          }
          Text(job.fileName)
            .font(.caption)
            .lineLimit(1)
          Spacer()
          Text(job.preset.rawValue)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
      }
    }
    .padding(.bottom, 4)
  }

  // MARK: - Recent Results

  private var recentList: some View {
    VStack(alignment: .leading, spacing: 4) {
      Divider()
      Text("Recent")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.top, 6)

      ForEach(manager.recentResults.prefix(5), id: \.job.id) { result in
        HStack(spacing: 8) {
          Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(result.success ? .green : .red)
            .font(.caption)
          Text(result.displayName)
            .font(.caption)
            .lineLimit(1)
          Spacer()
          Text(result.outputSize)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 1)
      }
    }
    .padding(.bottom, 6)
  }

  // MARK: - Footer

  private var footer: some View {
    HStack {
      Text("tomp3")
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
      }
    }
    return true
  }
}
