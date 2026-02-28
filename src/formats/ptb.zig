/// PowerTab (.ptb) binary file format parser and writer.
///
/// The .ptb format uses little-endian byte order and stores strings as
/// length-prefixed byte arrays.  This module supports version 1.7 of the
/// format (the last version produced by the original PowerTab Editor 1.7).
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
const Technique = @import("../model/note.zig").Technique;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Magic bytes at the start of every .ptb file.
pub const PTB_MAGIC = "ptab";
pub const PTB_VERSION_MAJOR: u8 = 1;
pub const PTB_VERSION_MINOR: u8 = 7;

pub const ParseError = error{
    InvalidMagic,
    UnsupportedVersion,
    InvalidNoteString,
    InvalidNoteFret,
    UnexpectedEof,
    InvalidTimeSignature,
    TooManyStrings,
    TooManyMeasures,
};

// ---------------------------------------------------------------------------
// Low-level helpers
// ---------------------------------------------------------------------------

fn readString(reader: anytype, allocator: std.mem.Allocator) ![]u8 {
    const len = try reader.readInt(u8, .little);
    const buf = try allocator.alloc(u8, len);
    try reader.readNoEof(buf);
    return buf;
}

fn writeString(writer: anytype, s: []const u8) !void {
    try writer.writeInt(u8, @intCast(s.len), .little);
    try writer.writeAll(s);
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

/// Parse a .ptb file from the given byte slice.  Returns a `Song` whose
/// memory is backed by an ArenaAllocator initialised from `child_allocator`.
pub fn parse(data: []const u8, child_allocator: std.mem.Allocator) !Song {
    var stream = std.io.fixedBufferStream(data);
    const reader = stream.reader();

    // --- File header ---
    var magic: [4]u8 = undefined;
    try reader.readNoEof(&magic);
    if (!std.mem.eql(u8, &magic, PTB_MAGIC)) return ParseError.InvalidMagic;

    const version_major = try reader.readInt(u8, .little);
    const version_minor = try reader.readInt(u8, .little);
    if (version_major != PTB_VERSION_MAJOR) return ParseError.UnsupportedVersion;
    _ = version_minor;

    // Song type: 0 = guitar, 1 = bass (ignored for now)
    _ = try reader.readInt(u8, .little);

    var song = Song.init(child_allocator);
    errdefer song.deinit();
    const alloc = song.allocator();

    // --- Song info ---
    song.info.title = try readString(reader, alloc);
    song.info.artist = try readString(reader, alloc);
    song.info.album = try readString(reader, alloc);
    song.info.tab_by = try readString(reader, alloc);
    song.info.copyright = try readString(reader, alloc);
    song.info.instructions = try readString(reader, alloc);
    song.info.notes = try readString(reader, alloc);
    song.info.tempo = try reader.readInt(u16, .little);

    // --- Guitars ---
    const guitar_count = try reader.readInt(u8, .little);
    const guitars = try alloc.alloc(Guitar, guitar_count);
    for (guitars) |*g| {
        g.* = Guitar.initDefault("");
        g.name = try readString(reader, alloc);
        g.string_count = try reader.readInt(u8, .little);
        if (g.string_count > MAX_GUITAR_STRINGS) return ParseError.TooManyStrings;
        for (0..g.string_count) |si| {
            g.tuning[si] = try reader.readInt(u8, .little);
        }
        g.capo = try reader.readInt(u8, .little);
        g.midi_channel = try reader.readInt(u8, .little);
        g.midi_program = try reader.readInt(u8, .little);
        g.volume = try reader.readInt(u8, .little);
    }
    song.guitars = guitars;

    // --- Staves ---
    const staff_count = try reader.readInt(u8, .little);
    const staves = try alloc.alloc(Staff, staff_count);
    for (staves) |*st| {
        const guitar_idx = try reader.readInt(u8, .little);
        const measure_count = try reader.readInt(u16, .little);
        if (measure_count > 10_000) return ParseError.TooManyMeasures;
        const measures = try alloc.alloc(Measure, measure_count);
        for (measures) |*m| {
            const num = try reader.readInt(u8, .little);
            const den = try reader.readInt(u8, .little);
            if (den == 0) return ParseError.InvalidTimeSignature;
            const repeat_start_byte = try reader.readInt(u8, .little);
            const repeat_end = try reader.readInt(u8, .little);
            const pos_count = try reader.readInt(u16, .little);
            const positions = try alloc.alloc(Position, pos_count);
            for (positions) |*pos| {
                const dur_raw = try reader.readInt(u8, .little);
                const dur: Duration = @enumFromInt(@min(dur_raw, 6));
                const is_rest = try reader.readInt(u8, .little);
                const note_count = try reader.readInt(u8, .little);
                const notes = try alloc.alloc(Note, note_count);
                for (notes) |*n| {
                    const string_idx = try reader.readInt(u8, .little);
                    const fret = try reader.readInt(u8, .little);
                    const tech_raw = try reader.readInt(u16, .little);
                    if (string_idx >= 7) return ParseError.InvalidNoteString;
                    if (fret > 24) return ParseError.InvalidNoteFret;
                    n.* = .{
                        .string = string_idx,
                        .fret = fret,
                        .technique = @bitCast(tech_raw),
                    };
                }
                pos.* = Position.init(dur, notes, is_rest != 0);
            }
            m.* = Measure.init(num, den, positions);
            m.repeat_start = repeat_start_byte != 0;
            m.repeat_end = repeat_end;
        }
        st.* = Staff.init(guitar_idx, measures);
    }
    song.staves = staves;

    return song;
}

// ---------------------------------------------------------------------------
// Writer
// ---------------------------------------------------------------------------

/// Serialise a `Song` to the PTB binary format, writing into `writer`.
pub fn write(song: Song, writer: anytype) !void {
    // Header
    try writer.writeAll(PTB_MAGIC);
    try writer.writeInt(u8, PTB_VERSION_MAJOR, .little);
    try writer.writeInt(u8, PTB_VERSION_MINOR, .little);
    try writer.writeInt(u8, 0, .little); // song type = guitar

    // Song info
    try writeString(writer, song.info.title);
    try writeString(writer, song.info.artist);
    try writeString(writer, song.info.album);
    try writeString(writer, song.info.tab_by);
    try writeString(writer, song.info.copyright);
    try writeString(writer, song.info.instructions);
    try writeString(writer, song.info.notes);
    try writer.writeInt(u16, song.info.tempo, .little);

    // Guitars
    try writer.writeInt(u8, @intCast(song.guitars.len), .little);
    for (song.guitars) |g| {
        try writeString(writer, g.name);
        try writer.writeInt(u8, g.string_count, .little);
        for (0..g.string_count) |si| {
            try writer.writeInt(u8, g.tuning[si], .little);
        }
        try writer.writeInt(u8, g.capo, .little);
        try writer.writeInt(u8, g.midi_channel, .little);
        try writer.writeInt(u8, g.midi_program, .little);
        try writer.writeInt(u8, g.volume, .little);
    }

    // Staves
    try writer.writeInt(u8, @intCast(song.staves.len), .little);
    for (song.staves) |st| {
        try writer.writeInt(u8, st.guitar_index, .little);
        try writer.writeInt(u16, @intCast(st.measures.len), .little);
        for (st.measures) |m| {
            try writer.writeInt(u8, m.numerator, .little);
            try writer.writeInt(u8, m.denominator, .little);
            try writer.writeInt(u8, if (m.repeat_start) 1 else 0, .little);
            try writer.writeInt(u8, m.repeat_end, .little);
            try writer.writeInt(u16, @intCast(m.positions.len), .little);
            for (m.positions) |pos| {
                try writer.writeInt(u8, @intFromEnum(pos.duration), .little);
                try writer.writeInt(u8, if (pos.rest) 1 else 0, .little);
                try writer.writeInt(u8, @intCast(pos.notes.len), .little);
                for (pos.notes) |n| {
                    try writer.writeInt(u8, n.string, .little);
                    try writer.writeInt(u8, n.fret, .little);
                    try writer.writeInt(u16, @bitCast(n.technique), .little);
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "PTB roundtrip – empty song" {
    var original = Song.init(std.testing.allocator);
    defer original.deinit();
    original.info.title = "Test Song";
    original.info.artist = "Test Artist";
    original.info.tempo = 140;

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try write(original, buf.writer());

    var parsed = try parse(buf.items, std.testing.allocator);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Test Song", parsed.info.title);
    try std.testing.expectEqualStrings("Test Artist", parsed.info.artist);
    try std.testing.expectEqual(@as(u16, 140), parsed.info.tempo);
    try std.testing.expectEqual(@as(usize, 0), parsed.staves.len);
}

test "PTB roundtrip – song with guitar and measure" {
    var original = Song.init(std.testing.allocator);
    defer original.deinit();
    const alloc = original.allocator();

    original.info.title = "Roundtrip";
    original.info.tempo = 120;

    // One guitar
    const guitars = try alloc.alloc(Guitar, 1);
    guitars[0] = Guitar.initDefault("Guitar 1");
    original.guitars = guitars;

    // One staff with one 4/4 measure containing a single quarter-note
    var note_buf = [_]Note{Note.init(0, 5)};
    const positions = try alloc.alloc(Position, 1);
    positions[0] = Position.init(.quarter, &note_buf, false);
    const measures = try alloc.alloc(Measure, 1);
    measures[0] = Measure.init(4, 4, positions);
    const staves = try alloc.alloc(Staff, 1);
    staves[0] = Staff.init(0, measures);
    original.staves = staves;

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try write(original, buf.writer());

    var parsed = try parse(buf.items, std.testing.allocator);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Roundtrip", parsed.info.title);
    try std.testing.expectEqual(@as(usize, 1), parsed.staves.len);
    try std.testing.expectEqual(@as(usize, 1), parsed.staves[0].measures.len);
    const pm = parsed.staves[0].measures[0];
    try std.testing.expectEqual(@as(u8, 4), pm.numerator);
    try std.testing.expectEqual(@as(u8, 4), pm.denominator);
    try std.testing.expectEqual(@as(usize, 1), pm.positions.len);
    try std.testing.expectEqual(Duration.quarter, pm.positions[0].duration);
    try std.testing.expectEqual(@as(usize, 1), pm.positions[0].notes.len);
    try std.testing.expectEqual(@as(u8, 0), pm.positions[0].notes[0].string);
    try std.testing.expectEqual(@as(u8, 5), pm.positions[0].notes[0].fret);
}

test "PTB parse error on bad magic" {
    const bad_data = "NOPE\x01\x07\x00";
    var song = parse(bad_data, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.InvalidMagic, err);
        return;
    };
    song.deinit();
    return error.TestExpectedError;
}

test "PTB parse error on unsupported version" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try buf.appendSlice(PTB_MAGIC);
    try buf.append(2); // major version 2 – unsupported
    try buf.append(0);
    try buf.append(0);

    var song = parse(buf.items, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.UnsupportedVersion, err);
        return;
    };
    song.deinit();
    return error.TestExpectedError;
}
