# powertab-zig

[![CI](https://github.com/christianhelle/powertab-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/powertab-zig/actions/workflows/ci.yml)
[![Zig 0.14](https://img.shields.io/badge/zig-0.14-orange?logo=zig)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A guitar tablature editor written in [Zig](https://ziglang.org/), inspired by the classic [PowerTab Editor](http://www.power-tab.net/guitar.php). Built with an immediate-mode rendering loop powered by [raylib](https://www.raylib.com/) for maximum performance.

## Features

- Open, edit and save **PowerTab** (`.ptb`) files
- **Import** Guitar Pro 3/4/5 (`.gp3` / `.gp4` / `.gp5`) files
- Vim-style **keyboard navigation** (`hjkl` + arrow keys)
- **Undo / redo** history (unlimited depth, capped at 256 entries)
- Multi-track display with per-string note entry
- **Immediate-mode UI** – the entire screen is redrawn every frame; no retained widget state

## Quick start

### Prerequisites

| Dependency | Version | Install |
|---|---|---|
| [Zig](https://ziglang.org/download/) | ≥ 0.14.0 | See ziglang.org |
| [raylib](https://www.raylib.com/) | ≥ 4.5 | `sudo apt install libraylib-dev` (Ubuntu) / `brew install raylib` (macOS) |

### Build and run

```bash
# Clone
git clone https://github.com/christianhelle/powertab-zig.git
cd powertab-zig

# Run tests (no raylib required)
zig build test

# Build the editor (requires libraylib-dev)
zig build --release=safe

# Launch
./zig-out/bin/powertab-zig                 # blank demo song
./zig-out/bin/powertab-zig my_tab.ptb      # open a PowerTab file
./zig-out/bin/powertab-zig my_tab.gp4      # open a Guitar Pro file
```

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `←` / `h` | Move cursor left (previous beat) |
| `→` / `l` | Move cursor right (next beat) |
| `↑` / `k` | Move cursor to lower string |
| `↓` / `j` | Move cursor to higher string |
| `[` | Previous measure |
| `]` | Next measure |
| `i` | Enter **INSERT** mode (type fret numbers) |
| `Esc` | Return to **NORMAL** mode |
| `1`–`5` | Set note duration (whole → sixteenth) |
| `Delete` / `x` | Delete note at cursor |

### Insert mode

Type one or two digits to enter a fret number (0–24). Press `Enter` to confirm a single digit, or the fret is committed automatically after two digits.

## Project structure

```
src/
  main.zig          Entry point
  lib.zig           Core library root (no external dependencies)

  model/            Pure data structures
    note.zig        Note, Duration, Technique
    chord.zig       ChordDiagram
    measure.zig     Measure, Position
    staff.zig       Staff
    guitar.zig      Guitar tuning / MIDI config
    song.zig        Song, SongInfo

  formats/          File format parsers / writers
    ptb.zig         PowerTab 1.7 binary format
    gp.zig          Guitar Pro 3 / 4 / 5 format

  editor/           Editor state
    cursor.zig      Grid cursor and navigation
    history.zig     Undo/redo edit stacks
    editor.zig      Top-level Editor struct

  ui/               Rendering and input (raylib)
    app.zig         Application loop
    renderer.zig    Immediate-mode tablature renderer
    input.zig       Keyboard / mouse mapping
    colors.zig      Colour palette
```

## File formats

### PowerTab (.ptb)

The `.ptb` binary format (version 1.7) stores song data in little-endian byte order with Pascal-style length-prefixed strings. The parser and writer live in `src/formats/ptb.zig`.

### Guitar Pro (.gp3 / .gp4 / .gp5)

Guitar Pro files begin with a version string (`"FICHIER GUITAR PRO v3/4/5"`) and store track/measure/beat data in little-endian format. The parser lives in `src/formats/gp.zig`.

## Running tests

```bash
zig build test --summary all
```

All tests reside in `src/lib.zig` (and the modules it imports). They cover the data model, file-format round-trips, cursor navigation, and undo/redo history.

## Installing as a snap (Ubuntu)

```bash
# Build the snap locally
snapcraft --use-lxd

# Install
sudo snap install powertab-zig_*.snap --dangerous
```

Or install from the Ubuntu Snap Store *(coming soon)*.

## Contributing

1. Fork and clone the repository.
2. Run `zig build test` – all tests should pass before you start.
3. Make your changes in small, focused commits.
4. Open a pull request against `main`.

See [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for architecture notes and coding conventions.

## Acknowledgements

- [PowerTab Editor](http://www.power-tab.net/guitar.php) – the original inspiration
- [powertabeditor](https://github.com/powertab/powertabeditor) – C++ reference implementation
- [raylib](https://www.raylib.com/) – simple and easy-to-use library for video games
- [Zig](https://ziglang.org/) – a general-purpose programming language and toolchain

## License

MIT – see [LICENSE](LICENSE).