/// Guitar Pro file format parser (.gp3 / .gp4 / .gp5).
///
/// Guitar Pro files begin with a version string and are stored in
/// little-endian byte order.  This module detects the file version and
/// parses the subset of the format needed to populate a `Song`.
const std = @import("std");
const Song = @import("../model/song.zig").Song;
const SongInfo = @import("../model/song.zig").SongInfo;
const guitar_mod = @import("../model/guitar.zig");
const Guitar = guitar_mod.Guitar;
const MAX_GUITAR_STRINGS = guitar_mod.MAX_STRINGS;
const Staff = @import("../model/staff.zig").Staff;
const Measure = @import("../model/measure.zig").Measure;
const Position = @import("../model/measure.zig").Position;
const Note = @import("../model/note.zig").Note;
const Duration = @import("../model/note.zig").Duration;

// ---------------------------------------------------------------------------
// Version detection
// ---------------------------------------------------------------------------

pub const GpVersion = enum {
    gp3,
    gp4,
    gp5,
};

pub const ParseError = error{
    UnknownVersion,
    UnexpectedEof,
    TooManyTracks,
    TooManyMeasures,
    InvalidStringCount,
    InvalidNoteValue,
};

/// Version magic strings (padded to 31 bytes with spaces / nulls in the file).
const GP3_MAGIC = "FICHIER GUITAR PRO v3";
const GP4_MAGIC = "FICHIER GUITAR PRO v4";
const GP5_MAGIC = "FICHIER GUITAR PRO v5";

/// Read the 31-byte Guitar Pro version header and return the detected version.
pub fn detectVersion(data: []const u8) ?GpVersion {
    if (data.len < 32) return null;
    // Byte 0 is the length byte (Pascal string).
    const tag_len = data[0];
    if (tag_len > 31) return null;
    const tag = data[1 .. 1 + tag_len];
    if (std.mem.startsWith(u8, tag, GP5_MAGIC)) return .gp5;
    if (std.mem.startsWith(u8, tag, GP4_MAGIC)) return .gp4;
    if (std.mem.startsWith(u8, tag, GP3_MAGIC)) return .gp3;
    return null;
}

// ---------------------------------------------------------------------------
// Low-level helpers
// ---------------------------------------------------------------------------

fn readPascalString(reader: anytype, buf: []u8) ![]u8 {
    const len = try reader.readInt(u8, .little);
    const actual = @min(len, buf.len);
    try reader.readNoEof(buf[0..actual]);
    if (len > actual) {
        // Discard remaining bytes
        var discard: [1]u8 = undefined;
        for (0..len - actual) |_| try reader.readNoEof(&discard);
    }
    return buf[0..actual];
}

/// Read a fixed-width Pascal string: length byte + `max_len` bytes of content
/// (the file always writes exactly `max_len` content bytes regardless of length).
fn readFixedPascalString(reader: anytype, allocator: std.mem.Allocator, max_len: usize) ![]u8 {
    const len = try reader.readInt(u8, .little);
    const buf = try allocator.alloc(u8, max_len);
    try reader.readNoEof(buf);
    const actual = @min(len, max_len);
    return buf[0..actual];
}

fn skipBytes(reader: anytype, count: usize) !void {
    var buf: [64]u8 = undefined;
    var remaining = count;
    while (remaining > 0) {
        const chunk = @min(remaining, buf.len);
        try reader.readNoEof(buf[0..chunk]);
        remaining -= chunk;
    }
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

pub fn parse(data: []const u8, child_allocator: std.mem.Allocator) !Song {
    var stream = std.io.fixedBufferStream(data);
    const reader = stream.reader();

    // Version string: 1 byte length + 31 bytes content (32 bytes total in file).
    var ver_buf: [31]u8 = undefined;
    const version_tag = try readPascalString(reader, &ver_buf);
    // Skip padding bytes to complete the 31-byte content block.
    if (version_tag.len < 31) try skipBytes(reader, 31 - version_tag.len);

    const version = blk: {
        if (std.mem.startsWith(u8, version_tag, GP5_MAGIC)) break :blk GpVersion.gp5;
        if (std.mem.startsWith(u8, version_tag, GP4_MAGIC)) break :blk GpVersion.gp4;
        if (std.mem.startsWith(u8, version_tag, GP3_MAGIC)) break :blk GpVersion.gp3;
        return ParseError.UnknownVersion;
    };

    var song = Song.init(child_allocator);
    errdefer song.deinit();
    const alloc = song.allocator();

    // --- Song attributes ---
    song.info.title = try readFixedPascalString(reader, alloc, 255);
    song.info.artist = try readFixedPascalString(reader, alloc, 255);
    song.info.album = try readFixedPascalString(reader, alloc, 255);
    _ = try readFixedPascalString(reader, alloc, 255); // words by
    song.info.copyright = try readFixedPascalString(reader, alloc, 255);
    song.info.tab_by = try readFixedPascalString(reader, alloc, 255);
    song.info.instructions = try readFixedPascalString(reader, alloc, 255);

    // Notice lines
    const notice_count = try reader.readInt(u32, .little);
    for (0..notice_count) |_| {
        _ = try readFixedPascalString(reader, alloc, 255);
    }

    // Triplet feel (GP3/GP4 only – not present in GP5 which uses a different structure)
    if (version != .gp5) {
        _ = try reader.readInt(u8, .little);
    }

    // Lyrics (GP4+) – skip
    if (version == .gp5) {
        _ = try reader.readInt(u32, .little); // lyrics track
        for (0..5) |_| {
            _ = try reader.readInt(u32, .little); // bar
            _ = try readFixedPascalString(reader, alloc, 4096);
        }
    }

    // Tempo
    song.info.tempo = @intCast(try reader.readInt(u32, .little));

    // Key / octave
    if (version == .gp3) {
        _ = try reader.readInt(u32, .little);
    } else {
        _ = try reader.readInt(u32, .little);
        _ = try reader.readInt(u8, .little);
    }

    // MIDI channels (GP3+): 64 × 11 bytes
    for (0..64) |_| {
        try skipBytes(reader, 11);
    }

    // Measure and track counts
    const measure_count = try reader.readInt(u32, .little);
    const track_count = try reader.readInt(u32, .little);
    if (track_count > 64) return ParseError.TooManyTracks;
    if (measure_count > 10_000) return ParseError.TooManyMeasures;

    // --- Measure headers ---
    const MeasureHeader = struct { num: u8, den: u8, repeat_start: bool, repeat_end: u8 };
    const measure_headers = try alloc.alloc(MeasureHeader, measure_count);
    for (measure_headers) |*mh| {
        const flags = try reader.readInt(u8, .little);
        var num: u8 = 4;
        var den: u8 = 4;
        var repeat_start = false;
        var repeat_end: u8 = 0;
        if (flags & 0x01 != 0) num = try reader.readInt(u8, .little);
        if (flags & 0x02 != 0) den = try reader.readInt(u8, .little);
        if (flags & 0x04 != 0) repeat_start = true;
        if (flags & 0x08 != 0) repeat_end = try reader.readInt(u8, .little);
        if (flags & 0x10 != 0) try skipBytes(reader, 2); // alternate endings
        if (flags & 0x20 != 0) {
            _ = try readFixedPascalString(reader, alloc, 255);
            try skipBytes(reader, 1); // text color
        }
        if (flags & 0x40 != 0) try skipBytes(reader, 4); // tempo change
        if (flags & 0x80 != 0) try skipBytes(reader, 1); // key change
        mh.* = .{ .num = num, .den = den, .repeat_start = repeat_start, .repeat_end = repeat_end };
    }

    // --- Track definitions ---
    const guitars = try alloc.alloc(Guitar, track_count);
    for (guitars) |*g| {
        g.* = Guitar.initDefault("");
        _ = try reader.readInt(u8, .little); // flags
        var name_buf: [40]u8 = undefined;
        const name_raw = try readPascalString(reader, &name_buf);
        // Pad to 40 bytes
        if (name_raw.len < 40) try skipBytes(reader, 40 - name_raw.len);
        const name_copy = try alloc.dupe(u8, name_raw);
        g.name = name_copy;
        const string_count = try reader.readInt(u32, .little);
        if (string_count > MAX_GUITAR_STRINGS) return ParseError.InvalidStringCount;
        g.string_count = @intCast(string_count);
        for (0..7) |si| {
            const pitch_raw = try reader.readInt(u32, .little);
            if (si < string_count) {
                g.tuning[si] = @intCast(@min(pitch_raw, 127));
            }
        }
        g.midi_program = @intCast(@min(try reader.readInt(u32, .little), 127));
        g.volume = @intCast(@min(try reader.readInt(u32, .little), 127));
        _ = try reader.readInt(u32, .little); // balance
        _ = try reader.readInt(u32, .little); // chorus
        _ = try reader.readInt(u32, .little); // reverb
        _ = try reader.readInt(u32, .little); // phaser
        _ = try reader.readInt(u32, .little); // tremolo
        g.capo = @intCast(@min(try reader.readInt(u32, .little), 24));
        _ = try reader.readInt(u32, .little); // color
    }
    song.guitars = guitars;

    // --- Beats per measure per track ---
    const staves = try alloc.alloc(Staff, track_count);
    for (staves, 0..) |*st, ti| {
        const measures = try alloc.alloc(Measure, measure_count);
        for (measures, 0..) |*m, mi| {
            const mh = measure_headers[mi];
            const beat_count = try reader.readInt(u32, .little);
            const positions = try alloc.alloc(Position, beat_count);
            for (positions) |*pos| {
                const flags = try reader.readInt(u8, .little);
                const dur_raw = try reader.readInt(i8, .little);
                const dur: Duration = switch (dur_raw) {
                    -2 => .whole,
                    -1 => .half,
                    0 => .quarter,
                    1 => .eighth,
                    2 => .sixteenth,
                    3 => .thirty_second,
                    4 => .sixty_fourth,
                    else => .quarter,
                };
                const is_rest = (flags & 0x40) != 0;
                if (flags & 0x01 != 0) try skipBytes(reader, 4); // duration/tuplet
                if (flags & 0x02 != 0) _ = try readFixedPascalString(reader, alloc, 255); // chord
                if (flags & 0x04 != 0) _ = try readFixedPascalString(reader, alloc, 255); // text
                if (flags & 0x08 != 0) try skipBytes(reader, 4); // effects
                if (flags & 0x10 != 0) try skipBytes(reader, 4); // mix table
                const string_flags = try reader.readInt(u8, .little);
                var note_list = std.ArrayList(Note).init(alloc);
                for (0..7) |si| {
                    if (string_flags & (@as(u8, 1) << @as(u3, @intCast(si))) != 0) {
                        const note_flags = try reader.readInt(u8, .little);
                        _ = note_flags;
                        const fret = try reader.readInt(u8, .little);
                        const dyn = try reader.readInt(u8, .little);
                        _ = dyn;
                        const fingering = try reader.readInt(u8, .little);
                        _ = fingering;
                        if (fret > 24) return ParseError.InvalidNoteValue;
                        try note_list.append(Note.init(@intCast(si), fret));
                    }
                }
                pos.* = Position.init(dur, try note_list.toOwnedSlice(), is_rest);
            }
            m.* = Measure.init(mh.num, mh.den, positions);
            m.repeat_start = mh.repeat_start;
            m.repeat_end = mh.repeat_end;
        }
        st.* = Staff.init(@intCast(ti), measures);
    }
    song.staves = staves;

    return song;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "detectVersion GP3" {
    var buf: [32]u8 = [_]u8{' '} ** 32;
    buf[0] = @intCast(GP3_MAGIC.len);
    @memcpy(buf[1 .. 1 + GP3_MAGIC.len], GP3_MAGIC);
    try std.testing.expectEqual(GpVersion.gp3, detectVersion(&buf).?);
}

test "detectVersion GP4" {
    var buf: [32]u8 = [_]u8{' '} ** 32;
    buf[0] = @intCast(GP4_MAGIC.len);
    @memcpy(buf[1 .. 1 + GP4_MAGIC.len], GP4_MAGIC);
    try std.testing.expectEqual(GpVersion.gp4, detectVersion(&buf).?);
}

test "detectVersion GP5" {
    var buf: [32]u8 = [_]u8{' '} ** 32;
    buf[0] = @intCast(GP5_MAGIC.len);
    @memcpy(buf[1 .. 1 + GP5_MAGIC.len], GP5_MAGIC);
    try std.testing.expectEqual(GpVersion.gp5, detectVersion(&buf).?);
}

test "detectVersion unknown returns null" {
    const buf = "INVALID_FORMAT_HEADER_BYTES_HERE!!".*;
    try std.testing.expect(detectVersion(&buf) == null);
}

test "detectVersion too short returns null" {
    try std.testing.expect(detectVersion("short") == null);
}
