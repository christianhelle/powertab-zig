/// Colour palette for the editor UI.
const std = @import("std");
const c = @cImport(@cInclude("raylib.h"));

pub const bg = c.Color{ .r = 30, .g = 30, .b = 30, .a = 255 };
pub const fg = c.Color{ .r = 220, .g = 220, .b = 220, .a = 255 };
pub const accent = c.Color{ .r = 66, .g = 135, .b = 245, .a = 255 };
pub const cursor_bg = c.Color{ .r = 66, .g = 135, .b = 245, .a = 80 };
pub const string_line = c.Color{ .r = 100, .g = 100, .b = 100, .a = 255 };
pub const bar_line = c.Color{ .r = 160, .g = 160, .b = 160, .a = 255 };
pub const note_text = c.Color{ .r = 255, .g = 220, .b = 100, .a = 255 };
pub const muted_text = c.Color{ .r = 160, .g = 80, .b = 80, .a = 255 };
pub const selected_note = c.Color{ .r = 100, .g = 230, .b = 100, .a = 255 };
pub const status_bar_bg = c.Color{ .r = 20, .g = 20, .b = 45, .a = 255 };
pub const status_bar_fg = c.Color{ .r = 180, .g = 200, .b = 255, .a = 255 };
pub const title_fg = c.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const repeat_sign = c.Color{ .r = 255, .g = 160, .b = 60, .a = 255 };
