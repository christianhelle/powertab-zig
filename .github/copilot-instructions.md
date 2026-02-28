# powertab-zig – Copilot Instructions

`powertab-zig` is a high-performance guitar tablature editor written in Zig, reimplementing the classic PowerTab Editor with support for PowerTab (.ptb) and Guitar Pro (.gp3/.gp4/.gp5) file formats. It targets maximum performance using an immediate-mode rendering approach.

## Build, run, and test

```sh
zig build                      # compile → zig-out/bin/powertab
zig build run                  # build + run
zig build run -- --help        # build + run with args
zig build run -- --new         # create a new empty score
zig build run -- --info file   # show file info
zig build test                 # run all tests
zig build -Doptimize=ReleaseFast  # optimized build
```

There is no per-file test runner; individual test blocks are inline in their source files. To run all tests, use `zig build test` — it's fast because `main.zig` imports all modules transitively.

## Architecture

All source files live flat in `src/`. The data model follows the PowerTab Editor C++ project hierarchy:

```
main.zig ──────→ score.zig ──→ system.zig ──→ staff.zig ──→ position.zig ──→ note.zig
                    │               │
                    │               ├── barline.zig
                    │               └── music_theory.zig (key/time sig, tempo)
                    │
                    ├── player.zig (Player, Instrument, PlayerChange)
                    └── tuning.zig (guitar tunings)

ptb_format.zig ── PowerTab binary format parser/writer
gp_format.zig  ── Guitar Pro format parser
```

| File | Responsibility |
|---|---|
| `main.zig` | CLI entry point; arg parsing; imports all modules for transitive test coverage |
| `score.zig` | Top-level `Score` document: metadata, systems, players, instruments |
| `system.zig` | `System` — horizontal row of staves with barlines, tempo markers, directions, chord text |
| `staff.zig` | `Staff` and `Voice` containers for positions |
| `position.zig` | `Position` — rhythmic location with duration, properties, and notes |
| `note.zig` | `Note` — string/fret with bitflag properties (tied, muted, hammer-on, bend, trill, etc.) |
| `barline.zig` | `Barline` types (single, double, repeat) with optional key/time signature changes |
| `player.zig` | `Player` (musician + tuning) and `Instrument` (MIDI preset + effects) |
| `tuning.zig` | `Tuning` — string note values with presets (standard, drop D, bass) |
| `music_theory.zig` | `KeySignature`, `TimeSignature`, `TempoMarker`, MIDI note utilities |
| `ptb_format.zig` | PowerTab v1.7 binary format reader/writer with validation |
| `gp_format.zig` | Guitar Pro v3/v4/v5 format reader |

## Key conventions

**Tests are inline.** Every `.zig` file contains `test` blocks directly. `main.zig` has an `"imports compile"` test that imports all modules, ensuring transitive test coverage.

**Fixed-size arrays for zero-allocation core model.** The score data model uses fixed-size arrays (no heap allocations) for maximum cache locality and predictable performance. Array sizes are tuned to fit on the stack while supporting reasonable score complexity.

**Bitflag properties.** `Note` and `Position` use `u32` bitflags for boolean properties (tied, muted, hammer-on, etc.) with type-safe enum-based accessors.

**Binary format parsing.** Both `ptb_format.zig` and `gp_format.zig` use explicit little-endian byte reading with bounds checking. All reads return errors on unexpected EOF or invalid data.

**String fields use fixed buffers.** Names, titles, and descriptions use `[N]u8` arrays with a separate `_len` field, avoiding heap allocation for metadata.

**Source control:** Commit progress to git in small logical chunks with clear one-liner messages. Always create a branch for new features or bug fixes. When working locally, do not change the committer to Copilot and do not add a Co-Author line.
