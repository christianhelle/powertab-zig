/// Main application loop using raylib.
const std = @import("std");
const c = @cImport(@cInclude("raylib.h"));
const renderer = @import("renderer.zig");
const input = @import("input.zig");
const Editor = @import("../editor/editor.zig").Editor;
const Song = @import("../model/song.zig").Song;
const Guitar = @import("../model/guitar.zig").Guitar;
const Staff = @import("../model/staff.zig").Staff;
const Measure = @import("../model/measure.zig").Measure;
const Position = @import("../model/measure.zig").Position;
const Note = @import("../model/note.zig").Note;
const ptb = @import("../formats/ptb.zig");
const gp = @import("../formats/gp.zig");

const WINDOW_TITLE = "PowerTab Editor";
const DEFAULT_WIDTH = 1280;
const DEFAULT_HEIGHT = 720;
const TARGET_FPS = 60;

/// Run the application with the given allocator.  Blocks until the window is closed.
pub fn run(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    var editor = Editor.init(allocator);
    defer editor.deinit();

    // Load a file if provided on the command line
    if (args.len > 1) {
        loadFile(&editor, args[1], allocator) catch |err| {
            std.log.err("Failed to load '{s}': {}", .{ args[1], err });
        };
    } else {
        // Start with a demo song so the editor is not empty
        buildDemoSong(&editor) catch {};
    }

    c.InitWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT, WINDOW_TITLE);
    defer c.CloseWindow();
    c.SetTargetFPS(TARGET_FPS);
    c.SetWindowState(c.FLAG_WINDOW_RESIZABLE);

    var render_state = renderer.RenderState{};

    while (!c.WindowShouldClose()) {
        // --- Input ---
        input.processInput(&editor);

        // --- Draw ---
        c.BeginDrawing();
        renderer.drawFrame(
            &editor.song,
            editor.cursor,
            editor.mode,
            &render_state,
            c.GetScreenWidth(),
            c.GetScreenHeight(),
        );
        c.EndDrawing();
    }
}

// ---------------------------------------------------------------------------
// File loading
// ---------------------------------------------------------------------------

fn loadFile(editor: *Editor, path: []const u8, allocator: std.mem.Allocator) !void {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024 * 1024);
    defer allocator.free(data);

    // Detect format by extension and magic bytes
    if (std.mem.endsWith(u8, path, ".ptb")) {
        editor.song.deinit();
        editor.song = try ptb.parse(data, allocator);
    } else if (std.mem.endsWith(u8, path, ".gp3") or
        std.mem.endsWith(u8, path, ".gp4") or
        std.mem.endsWith(u8, path, ".gp5"))
    {
        editor.song.deinit();
        editor.song = try gp.parse(data, allocator);
    } else {
        // Try to auto-detect by content
        if (gp.detectVersion(data) != null) {
            editor.song.deinit();
            editor.song = try gp.parse(data, allocator);
        } else {
            editor.song.deinit();
            editor.song = try ptb.parse(data, allocator);
        }
    }
    editor.file_path = path;
}

// ---------------------------------------------------------------------------
// Demo song
// ---------------------------------------------------------------------------

fn buildDemoSong(editor: *Editor) !void {
    const alloc = editor.song.allocator();

    editor.song.info.title = "Demo Song";
    editor.song.info.artist = "PowerTab Zig";
    editor.song.info.tempo = 120;

    // One guitar, standard tuning
    const guitars = try alloc.alloc(Guitar, 1);
    guitars[0] = Guitar.initDefault("Guitar 1");
    editor.song.guitars = guitars;

    // Two 4/4 measures with a simple pentatonic riff
    const riff: []const struct { s: u8, f: u8 } = &.{
        .{ .s = 1, .f = 0 }, .{ .s = 1, .f = 3 },
        .{ .s = 2, .f = 0 }, .{ .s = 2, .f = 2 },
    };

    const measures = try alloc.alloc(Measure, 2);
    for (measures) |*m| {
        const positions = try alloc.alloc(Position, riff.len);
        for (positions, riff) |*pos, r| {
            const notes = try alloc.alloc(Note, 1);
            notes[0] = Note.init(r.s, r.f);
            pos.* = Position.init(.quarter, notes, false);
        }
        m.* = Measure.init(4, 4, positions);
    }

    const staves = try alloc.alloc(Staff, 1);
    staves[0] = Staff.init(0, measures);
    editor.song.staves = staves;
}
