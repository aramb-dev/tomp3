# 🎵 tomp3

A fast, beautiful terminal tool for converting audio to MP3 — written in Swift.

```
OVERVIEW: 🎵  Fast, beautiful audio-to-MP3 converter.

USAGE: tomp3 [<file> ...] [--preset <preset>] [--output <dir>] [--batch] [--open] [--quiet]
```

## Features

- 🎚️ **5 quality presets** — from ultra-compact voice (`tiny`) to full stereo (`high`)
- 📁 **Batch conversion** — convert entire folders in parallel
- ⚡ **Non-interactive mode** — fully scriptable with flags
- 🔍 **Self-update checker** — notifies you when a new version is available
- 📂 **Open in Finder** — reveal output folder after conversion
- 🔇 **Quiet mode** — pipe-safe output for scripting
- 🐚 **Shell completions** — bash, zsh, and fish supported

## Install

### Homebrew (recommended)

```sh
brew tap aramb-dev/tap
brew install tomp3
```

### Build from source

Requires Swift 5.9+ and Xcode command-line tools.

```sh
git clone https://github.com/aramb-dev/tomp3
cd tomp3
swift build -c release
cp .build/release/tomp3 ~/.local/bin/
```

### Dependencies

- **ffmpeg** — installed automatically via Homebrew if missing

## Usage

### Interactive mode

```sh
tomp3
```

Prompts you for a file path and quality preset.

### Single file

```sh
tomp3 interview.wav
tomp3 lecture.m4a --preset small
tomp3 music.flac --preset high --output ~/Music/converted/
```

### Batch convert a folder

```sh
tomp3 --batch ./recordings/ --preset tiny
tomp3 --batch ./recordings/ --preset medium --output ./out/ --open
```

### Batch via glob

```sh
tomp3 *.wav --preset standard
tomp3 ~/Podcasts/*.m4a --preset small --output ~/Podcasts/mp3/
```

### Scripting / piping

```sh
# Quiet mode: prints only the output path (or errors to stderr)
tomp3 input.wav --preset tiny --quiet
# → /path/to/input_tiny.mp3

# Use in a pipeline
tomp3 clip.m4a -p small -q | xargs afplay
```

## Quality Presets

| Preset     | Bitrate   | Sample Rate | Channels | Best for                    |
|------------|-----------|-------------|----------|-----------------------------|
| `tiny`     | ~15 kbps  | 16 kHz      | Mono     | Ultra-compact voice         |
| `small`    | ~27 kbps  | 16 kHz      | Mono     | Lectures, podcasts          |
| `medium`   | ~43 kbps  | 22 kHz      | Mono     | Clear speech, balanced      |
| `standard` | ~130 kbps | 44 kHz      | Mono     | Music, general use          |
| `high`     | ~190 kbps | 44 kHz      | Stereo   | Best quality                |

## All Options

```
OPTIONS:
  -p, --preset <preset>   Quality preset: tiny | small | medium | standard | high
  -o, --output <dir>      Output directory (defaults to same folder as input)
  -j, --jobs <n>          Max parallel jobs for batch mode (default: CPU count)
  --batch                 Scan a directory for all audio files
  --open                  Open output folder in Finder when done
  -q, --quiet             Suppress output; print only output path (or errors to stderr)
  --no-update-check       Skip the update check
  --version               Show version
  -h, --help              Show help
```

## Shell Completions

```sh
# zsh
tomp3 --generate-completion-script zsh > ~/.zsh/completions/_tomp3

# bash
tomp3 --generate-completion-script bash > /usr/local/etc/bash_completion.d/tomp3

# fish
tomp3 --generate-completion-script fish > ~/.config/fish/completions/tomp3.fish
```

## Supported Input Formats

Any format ffmpeg supports, including:
`mp3` `m4a` `wav` `aac` `flac` `ogg` `opus` `wma` `aiff` `webm` `mp4` `mkv` `mov`

## License

MIT — see [LICENSE](LICENSE)
