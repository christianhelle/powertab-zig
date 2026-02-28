/// Core editor state: ties the song model, cursor, and history together.
const std = @import("std");
const Song = @import("../model/song.zig").Song;
const SongInfo = @import("../model/song.zig").SongInfo;
const Guitar = @import("../model/guitar.zig").Guitar;
const Staff = @import("../model/staff.zig").Staff;
const Measure = @import("../model/measure.zig").Measure;
const Position = @import("../model/measure.zig").Position;
const Note = @import("../model/note.zig").Note;
const Duration = @import("../model/note.zig").Duration;
const Cursor = @import("cursor.zig").Cursor;
const History = @import("history.zig").History;
const EditKind = @import("history.zig").EditKind;

pub const EditorMode = enum {
    normal, // navigation
    insert, // entering note fret values
};

pub const EditorError = error{
    InvalidStaff,
    InvalidMeasure,
    InvalidPosition,
    InvalidFret,
    OutOfMemory,
};

pub const Editor = struct {
    song: Song,
    cursor: Cursor,
    history: History,
    mode: EditorMode,
    /// The duration to use when inserting new notes.
    active_duration: Duration,
    /// Path of the currently open file (empty if unsaved).
    file_path: []const u8,

    pub fn init(child_allocator: std.mem.Allocator) Editor {
        return .{
            .song = Song.init(child_allocator),
            .cursor = Cursor.init(),
            .history = History.init(child_allocator),
            .mode = .normal,
            .active_duration = .quarter,
            .file_path = "",
        };
    }

    pub fn deinit(self: *Editor) void {
        self.song.deinit();
        self.history.deinit();
    }

    // -----------------------------------------------------------------------
    // Navigation
    // -----------------------------------------------------------------------

    pub fn moveCursorLeft(self: *Editor) void {
        if (self.currentMeasure()) |m| {
            _ = self.cursor.moveLeft(m.positions.len);
        }
    }

    pub fn moveCursorRight(self: *Editor) void {
        if (self.currentMeasure()) |m| {
            _ = self.cursor.moveRight(m.positions.len);
        }
    }

    pub fn moveCursorUp(self: *Editor) void {
        _ = self.cursor.moveUp();
    }

    pub fn moveCursorDown(self: *Editor) void {
        if (self.currentGuitar()) |g| {
            _ = self.cursor.moveDown(g.string_count);
        }
    }

    pub fn nextMeasure(self: *Editor) void {
        if (self.currentStaff()) |st| {
            _ = self.cursor.nextMeasure(st.measures.len);
        }
    }

    pub fn prevMeasure(self: *Editor) void {
        _ = self.cursor.prevMeasure();
    }

    // -----------------------------------------------------------------------
    // Note editing
    // -----------------------------------------------------------------------

    /// Insert a note at the current cursor position with the given fret.
    /// Does nothing and returns EditorError if the position is out of range.
    pub fn insertNote(self: *Editor, fret: u8) !void {
        if (fret > 24) return EditorError.InvalidFret;
        const st = self.currentStaffMut() orelse return EditorError.InvalidStaff;
        if (self.cursor.measure >= st.measures.len) return EditorError.InvalidMeasure;
        const m = &st.measures[self.cursor.measure];
        if (self.cursor.position >= m.positions.len) return EditorError.InvalidPosition;
        const pos = &m.positions[self.cursor.position];

        const n = Note.init(@intCast(self.cursor.string), fret);

        // Record for undo
        try self.history.record(.{ .note_added = .{
            .staff = self.cursor.staff,
            .measure = self.cursor.measure,
            .position = self.cursor.position,
            .note = n,
        } });

        // Replace any existing note on the same string
        for (pos.notes, 0..) |existing, i| {
            if (existing.string == n.string) {
                pos.notes[i] = n;
                return;
            }
        }

        // Append new note (requires mutable slice – rebuild via arena alloc)
        const alloc = self.song.allocator();
        const new_notes = try alloc.alloc(Note, pos.notes.len + 1);
        @memcpy(new_notes[0..pos.notes.len], pos.notes);
        new_notes[pos.notes.len] = n;
        pos.notes = new_notes;
    }

    /// Delete the note on the current string at the cursor position.
    pub fn deleteNote(self: *Editor) !void {
        const st = self.currentStaffMut() orelse return EditorError.InvalidStaff;
        if (self.cursor.measure >= st.measures.len) return EditorError.InvalidMeasure;
        const m = &st.measures[self.cursor.measure];
        if (self.cursor.position >= m.positions.len) return EditorError.InvalidPosition;
        const pos = &m.positions[self.cursor.position];

        for (pos.notes, 0..) |n, i| {
            if (n.string == @as(u8, @intCast(self.cursor.string))) {
                try self.history.record(.{ .note_removed = .{
                    .staff = self.cursor.staff,
                    .measure = self.cursor.measure,
                    .position = self.cursor.position,
                    .note = n,
                } });
                // Remove by swapping with last element
                pos.notes[i] = pos.notes[pos.notes.len - 1];
                pos.notes = pos.notes[0 .. pos.notes.len - 1];
                return;
            }
        }
    }

    /// Change the active duration.
    pub fn setDuration(self: *Editor, dur: Duration) !void {
        _ = self;
        _ = dur;
        // TODO: also change the current position's duration and record history
    }

    // -----------------------------------------------------------------------
    // Accessors
    // -----------------------------------------------------------------------

    pub fn currentStaff(self: *const Editor) ?Staff {
        if (self.cursor.staff >= self.song.staves.len) return null;
        return self.song.staves[self.cursor.staff];
    }

    pub fn currentStaffMut(self: *Editor) ?*Staff {
        if (self.cursor.staff >= self.song.staves.len) return null;
        return &self.song.staves[self.cursor.staff];
    }

    pub fn currentMeasure(self: *const Editor) ?Measure {
        const st = self.currentStaff() orelse return null;
        if (self.cursor.measure >= st.measures.len) return null;
        return st.measures[self.cursor.measure];
    }

    pub fn currentGuitar(self: *const Editor) ?Guitar {
        const st = self.currentStaff() orelse return null;
        if (st.guitar_index >= self.song.guitars.len) return null;
        return self.song.guitars[st.guitar_index];
    }

    pub fn canUndo(self: *const Editor) bool {
        return self.history.canUndo();
    }

    pub fn canRedo(self: *const Editor) bool {
        return self.history.canRedo();
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn makeTestEditor(allocator: std.mem.Allocator) !Editor {
    var ed = Editor.init(allocator);
    const song_alloc = ed.song.allocator();

    // One guitar
    const guitars = try song_alloc.alloc(Guitar, 1);
    guitars[0] = Guitar.initDefault("Guitar 1");
    ed.song.guitars = guitars;

    // One staff with one 4/4 measure of four quarter-note positions
    const notes_buf = try song_alloc.alloc(Note, 0);
    var positions: [4]Position = undefined;
    for (&positions) |*p| p.* = Position.init(.quarter, notes_buf, false);
    const pos_slice = try song_alloc.dupe(Position, &positions);
    const measures = try song_alloc.alloc(Measure, 1);
    measures[0] = Measure.init(4, 4, pos_slice);
    const staves = try song_alloc.alloc(Staff, 1);
    staves[0] = Staff.init(0, measures);
    ed.song.staves = staves;

    return ed;
}

test "Editor.init" {
    var ed = Editor.init(std.testing.allocator);
    defer ed.deinit();
    try std.testing.expectEqual(EditorMode.normal, ed.mode);
}

test "Editor navigation" {
    var ed = try makeTestEditor(std.testing.allocator);
    defer ed.deinit();

    ed.moveCursorRight();
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.position);
    ed.moveCursorLeft();
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.position);
}

test "Editor.insertNote" {
    var ed = try makeTestEditor(std.testing.allocator);
    defer ed.deinit();

    try ed.insertNote(5);
    const m = ed.currentMeasure().?;
    try std.testing.expectEqual(@as(usize, 1), m.positions[0].notes.len);
    try std.testing.expectEqual(@as(u8, 5), m.positions[0].notes[0].fret);
}

test "Editor.insertNote invalid fret" {
    var ed = try makeTestEditor(std.testing.allocator);
    defer ed.deinit();

    const result = ed.insertNote(25);
    try std.testing.expectError(EditorError.InvalidFret, result);
}

test "Editor.deleteNote" {
    var ed = try makeTestEditor(std.testing.allocator);
    defer ed.deinit();

    try ed.insertNote(7);
    try ed.deleteNote();
    const m = ed.currentMeasure().?;
    try std.testing.expectEqual(@as(usize, 0), m.positions[0].notes.len);
}

test "Editor canUndo after insertNote" {
    var ed = try makeTestEditor(std.testing.allocator);
    defer ed.deinit();

    try std.testing.expect(!ed.canUndo());
    try ed.insertNote(3);
    try std.testing.expect(ed.canUndo());
}
