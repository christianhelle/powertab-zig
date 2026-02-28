/// Immediate-mode tab renderer using raylib.
///
/// Each frame the full visible portion of the tablature is redrawn from
/// scratch: no retained widget state is kept between frames.
const std = @import("std");
const c = @cImport(@cInclude("raylib.h"));
const colors = @import("colors.zig");
const Song = @import("../model/song.zig").Song;
const Staff = @import("../model/staff.zig").Staff;
const Measure = @import("../model/measure.zig").Measure;
const Position = @import("../model/measure.zig").Position;
const Note = @import("../model/note.zig").Note;
const Guitar = @import("../model/guitar.zig").Guitar;
const Cursor = @import("../editor/cursor.zig").Cursor;
const EditorMode = @import("../editor/editor.zig").EditorMode;

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const HEADER_H: i32 = 50;
const STATUS_H: i32 = 30;
const STAFF_TOP_PAD: i32 = 20;
const STRING_SPACING: i32 = 18;
const BEAT_WIDTH: i32 = 40;
const MEASURE_GAP: i32 = 20;
const FONT_SIZE: i32 = 14;
const STAFF_LABEL_W: i32 = 24;

/// Pixel y-coordinate of a string within a staff area.
fn stringY(staff_top: i32, string_idx: usize) i32 {
    return staff_top + @as(i32, @intCast(string_idx)) * STRING_SPACING;
}

/// Width in pixels for a single measure given the number of positions.
fn measureWidth(position_count: usize) i32 {
    return STAFF_LABEL_W + @as(i32, @intCast(position_count)) * BEAT_WIDTH + MEASURE_GAP;
}

// ---------------------------------------------------------------------------
// Public draw function
// ---------------------------------------------------------------------------

pub const RenderState = struct {
    /// Horizontal scroll offset in pixels.
    scroll_x: i32 = 0,
    /// Vertical scroll offset in pixels.
    scroll_y: i32 = 0,
};

/// Draw the entire editor UI for one frame.
pub fn drawFrame(
    song: *const Song,
    cursor: Cursor,
    mode: EditorMode,
    state: *RenderState,
    screen_w: i32,
    screen_h: i32,
) void {
    c.ClearBackground(colors.bg);

    // --- Header bar ---
    drawHeader(song, screen_w);

    // --- Staff area ---
    const staff_area_top = HEADER_H;
    const staff_area_bottom = screen_h - STATUS_H;
    _ = staff_area_bottom;

    var staff_y = staff_area_top + STAFF_TOP_PAD - state.scroll_y;
    for (song.staves, 0..) |st, si| {
        const guitar = if (st.guitar_index < song.guitars.len)
            &song.guitars[st.guitar_index]
        else
            null;
        const string_count: usize = if (guitar) |g| g.string_count else 6;
        const staff_h = @as(i32, @intCast(string_count - 1)) * STRING_SPACING + STRING_SPACING;

        drawStaff(st, si, cursor, string_count, staff_y, state.scroll_x, screen_w, guitar);

        staff_y += staff_h + STAFF_TOP_PAD * 2;
    }

    // --- Status bar ---
    drawStatusBar(song, cursor, mode, screen_w, screen_h);

    // --- Scroll with mouse wheel ---
    const wheel = c.GetMouseWheelMove();
    state.scroll_y -= @as(i32, @intFromFloat(wheel * 30.0));
    if (state.scroll_y < 0) state.scroll_y = 0;
}

// ---------------------------------------------------------------------------
// Sub-routines
// ---------------------------------------------------------------------------

fn drawHeader(song: *const Song, screen_w: i32) void {
    c.DrawRectangle(0, 0, screen_w, HEADER_H, c.Color{ .r = 20, .g = 20, .b = 40, .a = 255 });

    var title_buf: [128]u8 = undefined;
    const title = std.fmt.bufPrintZ(&title_buf, "{s}  —  {s}  ({d} BPM)", .{
        song.info.title,
        song.info.artist,
        song.info.tempo,
    }) catch "PowerTab Editor";
    c.DrawText(title.ptr, 10, 16, 18, colors.title_fg);
}

fn drawStaff(
    st: Staff,
    staff_idx: usize,
    cursor: Cursor,
    string_count: usize,
    staff_top: i32,
    scroll_x: i32,
    screen_w: i32,
    guitar: ?*const Guitar,
) void {
    // Draw string name labels (e B G D A E)
    const std_names = [6][]const u8{ "e", "B", "G", "D", "A", "E" };
    for (0..string_count) |si| {
        const sy = stringY(staff_top, si);
        // Draw horizontal string line
        c.DrawLine(STAFF_LABEL_W, sy, screen_w, sy, colors.string_line);
        // Label
        const label = if (si < std_names.len) std_names[si] else "?";
        c.DrawText(label.ptr, 4, sy - FONT_SIZE / 2, FONT_SIZE, colors.fg);
    }

    // Draw measures
    var x: i32 = STAFF_LABEL_W - scroll_x;
    for (st.measures, 0..) |m, mi| {
        const mw = measureWidth(m.positions.len);
        if (x + mw < 0) {
            x += mw;
            continue;
        }
        if (x > screen_w) break;

        drawMeasure(m, mi, staff_idx, cursor, string_count, staff_top, x, guitar);
        // Draw bar line at the right edge of this measure
        const bar_x = x + mw - MEASURE_GAP / 2;
        const bottom_y = stringY(staff_top, string_count - 1);
        c.DrawLine(bar_x, staff_top, bar_x, bottom_y, colors.bar_line);

        // Repeat start marker
        if (m.repeat_start) {
            c.DrawLine(x, staff_top, x, bottom_y, colors.repeat_sign);
            c.DrawLine(x + 2, staff_top, x + 2, bottom_y, colors.repeat_sign);
        }
        // Repeat end marker
        if (m.repeat_end > 0) {
            c.DrawLine(bar_x - 2, staff_top, bar_x - 2, bottom_y, colors.repeat_sign);
        }

        x += mw;
    }
}

fn drawMeasure(
    m: Measure,
    measure_idx: usize,
    staff_idx: usize,
    cursor: Cursor,
    string_count: usize,
    staff_top: i32,
    measure_x: i32,
    guitar: ?*const Guitar,
) void {
    _ = guitar;
    for (m.positions, 0..) |pos, pi| {
        const beat_x = measure_x + STAFF_LABEL_W + @as(i32, @intCast(pi)) * BEAT_WIDTH;
        const is_cursor = staff_idx == cursor.staff and
            measure_idx == cursor.measure and
            pi == cursor.position;

        // Cursor highlight rectangle
        if (is_cursor) {
            const bottom_y = stringY(staff_top, string_count - 1);
            c.DrawRectangle(
                beat_x - 2,
                staff_top - 2,
                BEAT_WIDTH - 2,
                bottom_y - staff_top + STRING_SPACING,
                colors.cursor_bg,
            );
        }

        for (pos.notes) |n| {
            if (n.string >= string_count) continue;
            const sy = stringY(staff_top, n.string);
            var fret_buf: [4]u8 = undefined;
            const fret_str = std.fmt.bufPrintZ(&fret_buf, "{d}", .{n.fret}) catch continue;
            const col = if (is_cursor and n.string == cursor.string)
                colors.selected_note
            else if (n.technique.muted)
                colors.muted_text
            else
                colors.note_text;
            // White background pill behind the fret number
            c.DrawRectangle(beat_x - 2, sy - 8, 20, 16, colors.bg);
            c.DrawText(fret_str.ptr, beat_x, sy - FONT_SIZE / 2, FONT_SIZE, col);
        }

        // Draw a dash for strings with no note
        for (0..string_count) |si| {
            const sy = stringY(staff_top, si);
            var has_note = false;
            for (pos.notes) |n| {
                if (n.string == si) { has_note = true; break; }
            }
            if (!has_note and !pos.rest) {
                c.DrawText("-", beat_x + 4, sy - FONT_SIZE / 2, FONT_SIZE, colors.string_line);
            }
        }
    }
}

fn drawStatusBar(
    song: *const Song,
    cursor: Cursor,
    mode: EditorMode,
    screen_w: i32,
    screen_h: i32,
) void {
    const bar_y = screen_h - STATUS_H;
    c.DrawRectangle(0, bar_y, screen_w, STATUS_H, colors.status_bar_bg);

    var buf: [256]u8 = undefined;
    const mode_str: []const u8 = switch (mode) {
        .normal => "NORMAL",
        .insert => "INSERT",
    };

    const measure_count = song.measureCount();
    const text = std.fmt.bufPrintZ(&buf, " {s}  |  Staff: {d}  Measure: {d}/{d}  Beat: {d}  String: {d}", .{
        mode_str,
        cursor.staff + 1,
        cursor.measure + 1,
        measure_count,
        cursor.position + 1,
        cursor.string + 1,
    }) catch return;
    c.DrawText(text.ptr, 0, bar_y + 8, FONT_SIZE, colors.status_bar_fg);
}
