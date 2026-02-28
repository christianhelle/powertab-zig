/// Keyboard and mouse input mapping.
const std = @import("std");
const c = @cImport(@cInclude("raylib.h"));
const Editor = @import("../editor/editor.zig").Editor;
const EditorMode = @import("../editor/editor.zig").EditorMode;
const Duration = @import("../model/note.zig").Duration;

/// Process all pending input events and mutate the editor state accordingly.
pub fn processInput(editor: *Editor) void {
    // --- Mode-independent shortcuts ---
    if (c.IsKeyPressed(c.KEY_ESCAPE)) {
        editor.mode = .normal;
    }

    switch (editor.mode) {
        .normal => processNormalMode(editor),
        .insert => processInsertMode(editor),
    }
}

fn processNormalMode(editor: *Editor) void {
    // Navigation
    if (c.IsKeyPressed(c.KEY_LEFT) or c.IsKeyPressed(c.KEY_H)) editor.moveCursorLeft();
    if (c.IsKeyPressed(c.KEY_RIGHT) or c.IsKeyPressed(c.KEY_L)) editor.moveCursorRight();
    if (c.IsKeyPressed(c.KEY_UP) or c.IsKeyPressed(c.KEY_K)) editor.moveCursorDown();
    if (c.IsKeyPressed(c.KEY_DOWN) or c.IsKeyPressed(c.KEY_J)) editor.moveCursorUp();
    if (c.IsKeyPressed(c.KEY_LEFT_BRACKET)) editor.prevMeasure();
    if (c.IsKeyPressed(c.KEY_RIGHT_BRACKET)) editor.nextMeasure();

    // Mode switch
    if (c.IsKeyPressed(c.KEY_I)) editor.mode = .insert;

    // Duration shortcuts (matching PowerTab convention)
    if (c.IsKeyPressed(c.KEY_ONE)) editor.active_duration = .whole;
    if (c.IsKeyPressed(c.KEY_TWO)) editor.active_duration = .half;
    if (c.IsKeyPressed(c.KEY_THREE)) editor.active_duration = .quarter;
    if (c.IsKeyPressed(c.KEY_FOUR)) editor.active_duration = .eighth;
    if (c.IsKeyPressed(c.KEY_FIVE)) editor.active_duration = .sixteenth;

    // Delete note under cursor
    if (c.IsKeyPressed(c.KEY_DELETE) or c.IsKeyPressed(c.KEY_X)) {
        editor.deleteNote() catch {};
    }
}

/// Accumulate digit keypresses to form a two-digit fret number.
var digit_buf: [2]u8 = .{ 0, 0 };
var digit_count: u8 = 0;

fn processInsertMode(editor: *Editor) void {
    // Accept digits 0-9; commit on Enter or when two digits are entered.
    const digits = [_]struct { key: c_int, val: u8 }{
        .{ .key = c.KEY_ZERO, .val = 0 },
        .{ .key = c.KEY_ONE, .val = 1 },
        .{ .key = c.KEY_TWO, .val = 2 },
        .{ .key = c.KEY_THREE, .val = 3 },
        .{ .key = c.KEY_FOUR, .val = 4 },
        .{ .key = c.KEY_FIVE, .val = 5 },
        .{ .key = c.KEY_SIX, .val = 6 },
        .{ .key = c.KEY_SEVEN, .val = 7 },
        .{ .key = c.KEY_EIGHT, .val = 8 },
        .{ .key = c.KEY_NINE, .val = 9 },
    };

    for (digits) |d| {
        if (c.IsKeyPressed(d.key)) {
            if (digit_count < 2) {
                digit_buf[digit_count] = d.val;
                digit_count += 1;
            }
            // After two digits, commit immediately
            if (digit_count == 2) {
                commitFret(editor);
            }
        }
    }

    if (c.IsKeyPressed(c.KEY_ENTER) or c.IsKeyPressed(c.KEY_KP_ENTER)) {
        if (digit_count > 0) commitFret(editor);
    }

    if (c.IsKeyPressed(c.KEY_BACKSPACE) and digit_count > 0) {
        digit_count -= 1;
    }
}

fn commitFret(editor: *Editor) void {
    var fret: u8 = 0;
    for (digit_buf[0..digit_count]) |d| fret = fret * 10 + d;
    digit_count = 0;
    editor.insertNote(fret) catch {};
    editor.moveCursorRight();
}
