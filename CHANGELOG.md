# Changelog

## v0.5
- Fixed emoji header rendering on fresh installs (UTF-8 locale issue)
- Added "by aramb-dev" to the header
- Universal binary (arm64 + x86_64) — runs natively on Intel and Apple Silicon

## v0.4
- `tomp3 update` — self-update command: checks, downloads, and installs silently with one password prompt
- `tomp3 update --check-only` — just checks if a newer version exists
- Live download progress bar

## v0.3
- Initial Swift CLI release (rewrite from zsh script)
- 5 quality presets: tiny → high
- Batch conversion with parallel jobs (`--batch`)
- Non-interactive / scriptable mode (`--quiet`, `-p`, `-o`)
- Shell completions (zsh, bash, fish)
- `--open` flag to reveal output in Finder
- Self-update check on launch
- Auto-installs ffmpeg via Homebrew if missing
- Signed + notarized `.pkg` installer
