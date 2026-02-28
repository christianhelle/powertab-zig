# PowerTab Editor – GitHub Copilot Instructions

## Project overview

**powertab-zig** is a Powertab / Guitar Pro tab editor written in [Zig](https://ziglang.org/) (≥ 0.14.0). It targets native desktop performance via an immediate-mode rendering loop built on [raylib](https://www.raylib.com/).

## Architecture

```
src/
  main.zig          Entry point; initialises GPA allocator and launches app
  lib.zig           Core library root (no external deps; used by tests)

  model/            Pure data structures (no I/O, no UI)
    note.zig        Note, Duration, Technique
    chord.zig       ChordDiagram
    measure.zig     Measure, Position
    staff.zig       Staff
    guitar.zig      Guitar tuning / MIDI config
    song.zig        Song, SongInfo (arena-allocated)

  formats/          Binary file format parsers / writers
    ptb.zig         PowerTab 1.7 format (.ptb)
    gp.zig          Guitar Pro 3/4/5 format (.gp3/.gp4/.gp5)

  editor/           Editor state (no rendering)
    cursor.zig      Grid cursor and navigation
    history.zig     Undo/redo via edit stacks
    editor.zig      Top-level Editor struct; ties model + cursor + history

  ui/               Rendering and input (depends on raylib)
    app.zig         Main application loop
    renderer.zig    Immediate-mode tablature renderer
    input.zig       Keyboard / mouse event mapping
    colors.zig      Colour palette
```

## Coding conventions

- **Memory**: All song data lives in an `ArenaAllocator` owned by `Song`. Free by calling `song.deinit()`. The UI uses the same GPA as `main.zig`. Avoid implicit allocations; always pass an explicit `std.mem.Allocator`.
- **Error handling**: Use `!T` error unions. Propagate with `try`, handle locally with `catch`. Prefer specific error sets (e.g. `ParseError`) over anonymous ones.
- **Testing**: Every module under `src/` should have embedded `test` blocks. Tests live in `src/lib.zig` (via `@import`) and are run with `zig build test`. Tests must **not** depend on raylib.
- **Naming**: `snake_case` for variables and functions, `PascalCase` for types and enums.
- **Zig version**: Target Zig 0.14.0. Do not use nightly-only APIs.
- **No global mutable state** outside of the single `RenderState` in `renderer.zig` and the digit buffer in `input.zig` (both justified by the immediate-mode design).

## File format notes

### PowerTab (.ptb)
- Magic bytes: `"ptab"` (4 bytes, ASCII)
- Version: `major.minor` (2 × `u8`, little-endian); currently 1.7
- Strings are length-prefixed (`u8` length + bytes, no null terminator)
- All multi-byte integers are **little-endian**
- Reference implementation: `src/formats/ptb.zig`

### Guitar Pro (.gp3 / .gp4 / .gp5)
- Version string: Pascal-encoded, padded to 31 bytes
- GP3 magic: `"FICHIER GUITAR PRO v3"`
- All multi-byte integers are **little-endian**
- Reference implementation: `src/formats/gp.zig`

## Dependency policy

- `src/lib.zig` and everything it transitively imports must **never** import `raylib`. This keeps the test build dependency-free.
- The UI layer (`src/ui/`) may import raylib via `@cImport(@cInclude("raylib.h"))`.
- New dependencies must be discussed before adding to `build.zig.zon`.

## Build commands

| Command | Purpose |
|---------|---------|
| `zig build test` | Run all unit tests (no raylib required) |
| `zig build` | Build the full editor (requires `libraylib-dev`) |
| `zig build run` | Build and launch the editor |
| `zig build --release=safe` | Release build with safety checks |

## Contributing

1. Write tests first (TDD encouraged for format parsers).
2. Run `zig build test` before every commit.
3. Keep commits small and focused – one logical change per commit.
4. Document public APIs with doc comments (`///`).
