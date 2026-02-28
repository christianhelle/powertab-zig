# powertab-zig

A high-performance guitar tablature editor written in [Zig](https://ziglang.org/), reimplementing the classic [PowerTab Editor](http://www.power-tab.net/guitar.php).

[![CI](https://github.com/christianhelle/powertab-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/powertab-zig/actions/workflows/ci.yml)

## Features

- **PowerTab format** (.ptb) — read/write support for the classic PowerTab v1.7 binary format
- **Guitar Pro format** (.gp3/.gp4/.gp5) — read support for Guitar Pro files
- **Zero-allocation core model** — fixed-size arrays for maximum cache locality
- **Comprehensive score model** — notes, positions, staves, systems, players, instruments, tunings
- **Music theory** — key signatures, time signatures, tempo markers, MIDI note utilities
- **Cross-platform** — Linux, macOS, Windows
- **High performance** — designed for immediate-mode rendering

## Installation

### Build from source

Requires [Zig](https://ziglang.org/download/):

```sh
zig build -Doptimize=ReleaseFast
```

The binary is at `zig-out/bin/powertab`.

### Snap (Ubuntu)

```sh
sudo snap install powertab
```

## Usage

```sh
# Show help
powertab --help

# Show version
powertab --version

# Create a new empty score
powertab --new

# Open a file (GUI mode - coming soon)
powertab song.ptb
```

## Supported File Formats

| Format | Extension | Read | Write |
|--------|-----------|------|-------|
| PowerTab v1.7 | `.ptb` | ✅ | ✅ |
| Guitar Pro 3 | `.gp3` | ✅ | — |
| Guitar Pro 4 | `.gp4` | ✅ | — |
| Guitar Pro 5 | `.gp5` | ✅ | — |

## Architecture

The score data model follows the hierarchy from the [PowerTab Editor C++](https://github.com/powertab/powertabeditor) project:

```
Score
├── ScoreInfo (title, artist, album, author, copyright)
├── Systems[] (horizontal rows of music)
│   ├── Staves[] (one per player/instrument)
│   │   └── Voices[] (up to 2 per staff)
│   │       └── Positions[] (rhythmic locations)
│   │           └── Notes[] (string + fret + properties)
│   ├── Barlines[] (with optional key/time signature changes)
│   ├── TempoMarkers[]
│   ├── Directions[] (coda, segno, etc.)
│   └── ChordTexts[]
├── Players[] (with tuning configuration)
└── Instruments[] (MIDI preset + effects)
```

## Development

```sh
zig build              # compile
zig build run          # build + run
zig build test         # run all unit tests
```

## License

MIT
