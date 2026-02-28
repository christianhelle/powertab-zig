/// Undo/redo history implemented as two stacks.
///
/// Each `Edit` captures a minimal diff so that both undo and redo are
/// possible without storing full song snapshots.
const std = @import("std");
const Note = @import("../model/note.zig").Note;
const Duration = @import("../model/note.zig").Duration;

// ---------------------------------------------------------------------------
// Edit kinds
// ---------------------------------------------------------------------------

pub const EditKind = union(enum) {
    /// A note was placed at a specific location.
    note_added: struct {
        staff: usize,
        measure: usize,
        position: usize,
        note: Note,
    },
    /// A note was removed from a specific location.
    note_removed: struct {
        staff: usize,
        measure: usize,
        position: usize,
        note: Note,
    },
    /// The duration of a beat was changed.
    duration_changed: struct {
        staff: usize,
        measure: usize,
        position: usize,
        old_duration: Duration,
        new_duration: Duration,
    },
    /// Song tempo was changed.
    tempo_changed: struct {
        old_tempo: u16,
        new_tempo: u16,
    },
};

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

pub const MAX_HISTORY = 256;

pub const History = struct {
    allocator: std.mem.Allocator,
    /// Stack of edits that can be undone.
    undo_stack: std.ArrayList(EditKind),
    /// Stack of edits that can be redone (cleared on new edit).
    redo_stack: std.ArrayList(EditKind),

    pub fn init(allocator: std.mem.Allocator) History {
        return .{
            .allocator = allocator,
            .undo_stack = std.ArrayList(EditKind).init(allocator),
            .redo_stack = std.ArrayList(EditKind).init(allocator),
        };
    }

    pub fn deinit(self: *History) void {
        self.undo_stack.deinit();
        self.redo_stack.deinit();
    }

    /// Record a new edit.  Clears the redo stack and trims the undo stack
    /// if it exceeds `MAX_HISTORY`.
    pub fn record(self: *History, edit: EditKind) !void {
        self.redo_stack.clearRetainingCapacity();
        if (self.undo_stack.items.len >= MAX_HISTORY) {
            _ = self.undo_stack.orderedRemove(0);
        }
        try self.undo_stack.append(edit);
    }

    /// Pop the most recent edit from the undo stack, push its inverse onto
    /// the redo stack, and return it so the caller can revert the song state.
    pub fn undo(self: *History) ?EditKind {
        const edit = self.undo_stack.popOrNull() orelse return null;
        self.redo_stack.append(edit) catch {};
        return edit;
    }

    /// Pop from the redo stack and re-apply.
    pub fn redo(self: *History) ?EditKind {
        const edit = self.redo_stack.popOrNull() orelse return null;
        self.undo_stack.append(edit) catch {};
        return edit;
    }

    pub fn canUndo(self: History) bool {
        return self.undo_stack.items.len > 0;
    }

    pub fn canRedo(self: History) bool {
        return self.redo_stack.items.len > 0;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "History.record and undo" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();

    try h.record(.{ .tempo_changed = .{ .old_tempo = 120, .new_tempo = 140 } });
    try std.testing.expect(h.canUndo());
    try std.testing.expect(!h.canRedo());

    const edit = h.undo().?;
    try std.testing.expectEqual(@as(u16, 120), edit.tempo_changed.old_tempo);
    try std.testing.expect(!h.canUndo());
    try std.testing.expect(h.canRedo());
}

test "History.redo after undo" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();

    try h.record(.{ .tempo_changed = .{ .old_tempo = 100, .new_tempo = 200 } });
    _ = h.undo();
    const edit = h.redo().?;
    try std.testing.expectEqual(@as(u16, 100), edit.tempo_changed.old_tempo);
}

test "History.record clears redo stack" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();

    try h.record(.{ .tempo_changed = .{ .old_tempo = 100, .new_tempo = 110 } });
    _ = h.undo();
    try std.testing.expect(h.canRedo());
    try h.record(.{ .tempo_changed = .{ .old_tempo = 100, .new_tempo = 120 } });
    try std.testing.expect(!h.canRedo());
}

test "History undo returns null on empty stack" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();
    try std.testing.expect(h.undo() == null);
}

test "History.record trims at MAX_HISTORY" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();

    for (0..MAX_HISTORY + 5) |i| {
        try h.record(.{ .tempo_changed = .{ .old_tempo = @intCast(i % 200), .new_tempo = @intCast((i + 1) % 200) } });
    }
    try std.testing.expectEqual(@as(usize, MAX_HISTORY), h.undo_stack.items.len);
}

test "History with note_added edit" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();

    const n = Note.init(2, 5);
    try h.record(.{ .note_added = .{ .staff = 0, .measure = 1, .position = 2, .note = n } });
    const edit = h.undo().?;
    try std.testing.expectEqual(@as(u8, 2), edit.note_added.note.string);
    try std.testing.expectEqual(@as(u8, 5), edit.note_added.note.fret);
}
