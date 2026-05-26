import ToMP3Core
import ArgumentParser
import Foundation

// MARK: - Help Command

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct HelpCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "help",
    abstract: "Show this help screen."
  )

  func run() {
    printHeader()

    let b  = Term.bold
    let r  = Term.reset
    let d  = Term.dim
    let c  = Term.cyan
    let g  = Term.green
    let y  = Term.yellow

    // ── Usage ────────────────────────────────────────────────────────────────
    print("  \(b)USAGE\(r)")
    print("    \(c)tomp3\(r) \(d)[file ...] [options]\(r)")
    print("    \(c)tomp3\(r) \(d)<subcommand> [options]\(r)")
    print("")

    // ── Quick examples ───────────────────────────────────────────────────────
    print("  \(b)EXAMPLES\(r)")
    row("tomp3",                        "interactive mode — prompts for file + preset")
    row("tomp3 interview.wav",          "convert one file (preset prompt follows)")
    row("tomp3 *.wav -p tiny",          "batch convert with the tiny preset")
    row("tomp3 --batch ./folder -p high --open", "batch a folder, open output in Finder")
    row("tomp3 update",                 "update to the latest release")
    print("")

    // ── Convert options ──────────────────────────────────────────────────────
    print("  \(b)CONVERT OPTIONS\(r)")
    opt("-p, --preset",    "tiny | small | medium | standard | high")
    opt("-o, --output",    "output directory  \(d)(default: same folder as input)\(r)")
    opt("-j, --jobs",      "max parallel jobs  \(d)(default: CPU count)\(r)")
    opt("    --batch",     "scan a directory for all audio files")
    opt("    --open",      "open output folder in Finder when done")
    opt("-q, --quiet",     "suppress all output except errors")
    opt("    --no-update-check", "skip the update check")
    print("")

    // ── Presets ──────────────────────────────────────────────────────────────
    print("  \(b)PRESETS\(r)")
    preset("tiny",     "~15 kbps · 16 kHz · mono",   "ultra compact, voice only")
    preset("small",    "~27 kbps · 16 kHz · mono",   "lectures, podcasts")
    preset("medium",   "~43 kbps · 22 kHz · mono",   "clear speech, balanced")
    preset("standard", "~130 kbps · 44 kHz · mono",  "music, general use")
    preset("high",     "~190 kbps · 44 kHz · stereo","best quality")
    print("")

    // ── Supported formats ─────────────────────────────────────────────────────
    print("  \(b)SUPPORTED INPUT FORMATS\(r)")
    print("    \(d)mp3  m4a  wav  aac  flac  ogg  opus  wma  aiff  webm  mp4  mkv  mov\(r)")
    print("")

    // ── Global flags ─────────────────────────────────────────────────────────
    print("  \(b)GLOBAL FLAGS\(r)")
    opt("-v, --version", "print version and exit")
    opt("-h, --help",    "show help for a subcommand")
    print("")

    // ── Version line ─────────────────────────────────────────────────────────
    print("  \(d)tomp3 v\(AppMeta.version) · \(g)github.com/aramb-dev/tomp3\(r)\(d) · by aramb-dev\(r)")
    print("")
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private func row(_ cmd: String, _ desc: String) {
    let padded = cmd.padding(toLength: 42, withPad: " ", startingAt: 0)
    print("    \(Term.cyan)\(padded)\(Term.reset)\(Term.dim)\(desc)\(Term.reset)")
  }

  private func opt(_ flag: String, _ desc: String) {
    let padded = flag.padding(toLength: 24, withPad: " ", startingAt: 0)
    print("    \(Term.bold)\(padded)\(Term.reset)  \(desc)")
  }

  private func preset(_ name: String, _ spec: String, _ note: String) {
    let namePad = name.padding(toLength: 10, withPad: " ", startingAt: 0)
    let specPad = spec.padding(toLength: 28, withPad: " ", startingAt: 0)
    print("    \(Term.cyan)\(Term.bold)\(namePad)\(Term.reset)  \(Term.dim)\(specPad)\(Term.reset)  \(note)")
  }
}
