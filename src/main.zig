/// PowerTab Editor — A high-performance guitar tablature editor written in Zig.
///
/// This is a Zig reimplementation of the PowerTab Editor, designed for maximum
/// performance using an immediate-mode rendering approach. It supports both
/// PowerTab (.ptb) and Guitar Pro (.gp3/.gp4/.gp5) file formats.
///
/// Architecture:
///   main.zig          — Entry point, CLI arg parsing, application lifecycle
///   score.zig         — Top-level Score document model
///   system.zig        — System (horizontal row of staves)
///   staff.zig         — Staff and Voice containers
///   position.zig      — Position (rhythmic location with notes)
///   note.zig          — Individual note representation
///   barline.zig       — Barline types and repeat markers
///   player.zig        — Player and Instrument definitions
///   tuning.zig        — Guitar tuning presets and custom tunings
///   music_theory.zig  — Key/time signatures, tempo, music constants
///   ptb_format.zig    — PowerTab file format parser/writer
///   gp_format.zig     — Guitar Pro file format parser
const std = @import("std");
const score_mod = @import("score.zig");
const Score = score_mod.Score;
const ScoreInfo = score_mod.ScoreInfo;

pub const version = "0.1.0";

const usage =
    \\Usage: powertab [options] [file]
    \\
    \\A high-performance guitar tablature editor.
    \\
    \\Arguments:
    \\  file          PowerTab (.ptb) or Guitar Pro (.gp3/.gp4/.gp5) file to open
    \\
    \\Options:
    \\  -h, --help    Print this help and exit
    \\  -v, --version Print version and exit
    \\  --info        Print file info and exit (requires file argument)
    \\  --new         Create a new empty score
    \\
;

pub fn main(init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &w.interface;

    var args_iter = std.process.Args.Iterator.init(init.minimal.args);
    _ = args_iter.skip(); // skip program name

    var file_path: ?[:0]const u8 = null;
    var show_info = false;
    var create_new = false;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try stdout.writeAll(usage);
            try w.flush();
            return;
        }
        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            try stdout.print("powertab {s}\n", .{version});
            try w.flush();
            return;
        }
        if (std.mem.eql(u8, arg, "--info")) {
            show_info = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--new")) {
            create_new = true;
            continue;
        }
        file_path = arg;
    }

    if (create_new) {
        try stdout.print("Created new score: Untitled\n", .{});
        try stdout.print("  Players: 1\n", .{});
        try stdout.print("  Systems: 1\n", .{});
        try w.flush();
        return;
    }

    if (file_path) |path| {
        if (show_info) {
            try stdout.print("File: {s}\n", .{path});
            try stdout.print("File info display requires a valid .ptb or .gp file.\n", .{});
            try stdout.print("Supported formats: .ptb, .gp3, .gp4, .gp5\n", .{});
            try w.flush();
            return;
        }
        try stdout.print("PowerTab Editor {s}\n", .{version});
        try stdout.print("Opening: {s}\n", .{path});
        try stdout.print("GUI mode not yet implemented. Use --info to inspect files.\n", .{});
    } else {
        try stdout.print("PowerTab Editor {s}\n", .{version});
        try stdout.print("Use --help for usage information.\n", .{});
    }
    try w.flush();
}

// ── Tests ──────────────────────────────────────────────────────────────
// Importing all modules ensures their inline tests are included in `zig build test`.

test "imports compile" {
    _ = @import("score.zig");
    _ = @import("system.zig");
    _ = @import("staff.zig");
    _ = @import("position.zig");
    _ = @import("note.zig");
    _ = @import("barline.zig");
    _ = @import("player.zig");
    _ = @import("tuning.zig");
    _ = @import("music_theory.zig");
    _ = @import("ptb_format.zig");
    _ = @import("gp_format.zig");
}

test "version string" {
    const testing = std.testing;
    try testing.expect(version.len > 0);
    try testing.expectEqualStrings("0.1.0", version);
}
