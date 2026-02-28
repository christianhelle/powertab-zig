/// Core library root – re-exports all modules so the test runner
/// picks up every `test` block in the codebase.
///
/// The library has no external dependencies and can be built and tested
/// without raylib installed.
pub const model = struct {
    pub const note = @import("model/note.zig");
    pub const chord = @import("model/chord.zig");
    pub const measure = @import("model/measure.zig");
    pub const staff = @import("model/staff.zig");
    pub const guitar = @import("model/guitar.zig");
    pub const song = @import("model/song.zig");
};

pub const formats = struct {
    pub const ptb = @import("formats/ptb.zig");
    pub const gp = @import("formats/gp.zig");
};

pub const editor = struct {
    pub const cursor = @import("editor/cursor.zig");
    pub const history = @import("editor/history.zig");
    pub const editor_mod = @import("editor/editor.zig");
};

// Ensure every test in every sub-module is compiled.
comptime {
    _ = model.note;
    _ = model.chord;
    _ = model.measure;
    _ = model.staff;
    _ = model.guitar;
    _ = model.song;
    _ = formats.ptb;
    _ = formats.gp;
    _ = editor.cursor;
    _ = editor.history;
    _ = editor.editor_mod;
}

test {
    @import("std").testing.refAllDecls(@This());
}
