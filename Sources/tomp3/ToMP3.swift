import ArgumentParser
import Foundation

// MARK: - Root command

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
@main
struct ToMP3: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tomp3",
    abstract: "Fast, beautiful audio-to-MP3 converter.",
    discussion: """
      Convert any audio (or video) file to MP3 with one command.
      Run without arguments for an interactive prompt, or pass files directly.

      Quick start:
        tomp3                         # interactive mode
        tomp3 recording.wav           # convert a single file (preset prompt)
        tomp3 *.wav -p tiny           # batch convert with tiny preset
        tomp3 --batch ./folder -p high --open
      """,
    version: AppMeta.version,
    subcommands: [ConvertCommand.self, UpdateCommand.self, HelpCommand.self],
    defaultSubcommand: ConvertCommand.self
  )
}
