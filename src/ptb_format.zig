/// PowerTab v1.7 file format parser (.ptb files).
/// The PowerTab format is a binary format used by the original
/// PowerTab Editor (released ~2000). This parser reads the legacy
/// binary format and converts it into our Score model.
///
/// File structure overview:
/// - Header: magic bytes, version, file type, song info
/// - Sections: guitar/bass score data
/// - Each section: staves, positions, notes, barlines, etc.
const std = @import("std");
const score_mod = @import("score.zig");
const system_mod = @import("system.zig");
const staff_mod = @import("staff.zig");
const position_mod = @import("position.zig");
const note_mod = @import("note.zig");
const player_mod = @import("player.zig");
const barline_mod = @import("barline.zig");
const music_theory = @import("music_theory.zig");

const Score = score_mod.Score;
const ScoreInfo = score_mod.ScoreInfo;
const System = system_mod.System;
const Staff = staff_mod.Staff;
const Voice = staff_mod.Voice;
const Position = position_mod.Position;
const DurationType = position_mod.DurationType;
const Note = note_mod.Note;
const Player = player_mod.Player;
const Instrument = player_mod.Instrument;
const Barline = barline_mod.Barline;
const BarlineType = barline_mod.BarlineType;

pub const PowerTabError = error{
    InvalidMagic,
    UnsupportedVersion,
    UnexpectedEndOfFile,
    InvalidData,
    BufferTooSmall,
};

/// PowerTab file magic bytes: "ptab\x04\x00"
pub const ptb_magic = [_]u8{ 'p', 't', 'a', 'b', 0x04, 0x00 };

/// PowerTab file version constants.
pub const FileVersion = struct {
    pub const v1_0: u16 = 1;
    pub const v1_5: u16 = 5;
    pub const v1_7: u16 = 7;
    pub const current: u16 = v1_7;
};

/// File type (guitar or bass).
pub const FileType = enum(u8) {
    guitar = 0,
    bass = 1,
};

/// PowerTab file header information.
pub const PtbHeader = struct {
    version: u16 = FileVersion.current,
    file_type: FileType = .guitar,

    pub fn eql(self: PtbHeader, other: PtbHeader) bool {
        return self.version == other.version and
            self.file_type == other.file_type;
    }
};

/// Reads a little-endian u16 from a byte slice.
pub fn readU16(data: []const u8, offset: usize) PowerTabError!u16 {
    if (offset + 2 > data.len) return PowerTabError.UnexpectedEndOfFile;
    return @as(u16, data[offset]) | (@as(u16, data[offset + 1]) << 8);
}

/// Reads a little-endian u32 from a byte slice.
pub fn readU32(data: []const u8, offset: usize) PowerTabError!u32 {
    if (offset + 4 > data.len) return PowerTabError.UnexpectedEndOfFile;
    return @as(u32, data[offset]) |
        (@as(u32, data[offset + 1]) << 8) |
        (@as(u32, data[offset + 2]) << 16) |
        (@as(u32, data[offset + 3]) << 24);
}

/// Reads a u8 from a byte slice.
pub fn readU8(data: []const u8, offset: usize) PowerTabError!u8 {
    if (offset >= data.len) return PowerTabError.UnexpectedEndOfFile;
    return data[offset];
}

/// Reads a length-prefixed string (u8 length + chars).
pub fn readString(data: []const u8, offset: usize, buf: []u8) PowerTabError!struct { len: u8, bytes_read: usize } {
    const str_len = try readU8(data, offset);
    if (offset + 1 + str_len > data.len) return PowerTabError.UnexpectedEndOfFile;
    const copy_len: u8 = @intCast(@min(str_len, @as(u8, @intCast(buf.len))));
    @memcpy(buf[0..copy_len], data[offset + 1 .. offset + 1 + copy_len]);
    return .{ .len = copy_len, .bytes_read = @as(usize, 1) + str_len };
}

/// Validates the PowerTab magic bytes at the start of a file.
pub fn validateMagic(data: []const u8) PowerTabError!void {
    if (data.len < ptb_magic.len) return PowerTabError.InvalidMagic;
    if (!std.mem.eql(u8, data[0..ptb_magic.len], &ptb_magic)) {
        return PowerTabError.InvalidMagic;
    }
}

/// Parses a PowerTab header from raw file data.
pub fn parseHeader(data: []const u8) PowerTabError!struct { header: PtbHeader, offset: usize } {
    try validateMagic(data);
    var offset: usize = ptb_magic.len;

    const version = try readU16(data, offset);
    offset += 2;

    const file_type_byte = try readU8(data, offset);
    offset += 1;

    const file_type: FileType = switch (file_type_byte) {
        0 => .guitar,
        1 => .bass,
        else => return PowerTabError.InvalidData,
    };

    return .{
        .header = .{
            .version = version,
            .file_type = file_type,
        },
        .offset = offset,
    };
}

/// Parse score info (title, artist, etc.) from the data stream.
pub fn parseScoreInfo(data: []const u8, start_offset: usize) PowerTabError!struct { info: ScoreInfo, offset: usize } {
    var info = ScoreInfo{};
    var offset = start_offset;

    // Title
    var title_buf: [128]u8 = undefined;
    const title_result = try readString(data, offset, &title_buf);
    info.setTitle(title_buf[0..title_result.len]);
    offset += title_result.bytes_read;

    // Artist
    var artist_buf: [128]u8 = undefined;
    const artist_result = try readString(data, offset, &artist_buf);
    info.setArtist(artist_buf[0..artist_result.len]);
    offset += artist_result.bytes_read;

    return .{ .info = info, .offset = offset };
}

/// Creates a minimal Score from parsed header and info.
pub fn createScoreFromHeader(header: PtbHeader, info: ScoreInfo) Score {
    var s = Score.init();
    s.info = info;

    // Set default player based on file type
    if (header.file_type == .bass) {
        s.players[0] = Player.init("Bass");
        s.players[0].tuning = @import("tuning.zig").Tuning.standardBass();
        s.instruments[0] = Instrument.init("Electric Bass", Instrument.electric_bass_finger);
    }

    return s;
}

/// Writes PowerTab magic bytes to a buffer.
pub fn writeMagic(buf: []u8) PowerTabError!usize {
    if (buf.len < ptb_magic.len) return PowerTabError.BufferTooSmall;
    @memcpy(buf[0..ptb_magic.len], &ptb_magic);
    return ptb_magic.len;
}

/// Writes a u16 as little-endian bytes.
pub fn writeU16(buf: []u8, offset: usize, value: u16) PowerTabError!usize {
    if (offset + 2 > buf.len) return PowerTabError.BufferTooSmall;
    buf[offset] = @intCast(value & 0xFF);
    buf[offset + 1] = @intCast((value >> 8) & 0xFF);
    return 2;
}

/// Writes a u8.
pub fn writeU8(buf: []u8, offset: usize, value: u8) PowerTabError!usize {
    if (offset >= buf.len) return PowerTabError.BufferTooSmall;
    buf[offset] = value;
    return 1;
}

/// Writes a length-prefixed string.
pub fn writeString(buf: []u8, offset: usize, str: []const u8) PowerTabError!usize {
    const len: u8 = @intCast(@min(str.len, 255));
    if (offset + 1 + len > buf.len) return PowerTabError.BufferTooSmall;
    buf[offset] = len;
    @memcpy(buf[offset + 1 .. offset + 1 + len], str[0..len]);
    return @as(usize, 1) + len;
}

/// Writes a complete PowerTab header to a buffer.
pub fn writeHeader(buf: []u8, header: PtbHeader) PowerTabError!usize {
    var offset: usize = 0;
    offset += try writeMagic(buf[offset..]);
    offset += try writeU16(buf, offset, header.version);
    offset += try writeU8(buf, offset, @intFromEnum(header.file_type));
    return offset;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "readU16 little-endian" {
    const testing = std.testing;
    const data = [_]u8{ 0x07, 0x00, 0xFF, 0x01 };
    try testing.expectEqual(@as(u16, 7), try readU16(&data, 0));
    try testing.expectEqual(@as(u16, 0x01FF), try readU16(&data, 2));
}

test "readU32 little-endian" {
    const testing = std.testing;
    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    try testing.expectEqual(@as(u32, 0x04030201), try readU32(&data, 0));
}

test "readU8" {
    const testing = std.testing;
    const data = [_]u8{ 42, 0 };
    try testing.expectEqual(@as(u8, 42), try readU8(&data, 0));
}

test "readString" {
    const testing = std.testing;
    const data = [_]u8{ 5, 'H', 'e', 'l', 'l', 'o' };
    var buf: [32]u8 = undefined;
    const result = try readString(&data, 0, &buf);
    try testing.expectEqual(@as(u8, 5), result.len);
    try testing.expectEqualStrings("Hello", buf[0..result.len]);
    try testing.expectEqual(@as(usize, 6), result.bytes_read);
}

test "validateMagic valid" {
    const testing = std.testing;
    var data: [32]u8 = undefined;
    @memcpy(data[0..ptb_magic.len], &ptb_magic);
    try validateMagic(&data);
    _ = testing;
}

test "validateMagic invalid" {
    const testing = std.testing;
    const data = [_]u8{ 'x', 'y', 'z', 0, 0, 0 };
    try testing.expectError(PowerTabError.InvalidMagic, validateMagic(&data));
}

test "validateMagic too short" {
    const testing = std.testing;
    const data = [_]u8{ 'p', 't' };
    try testing.expectError(PowerTabError.InvalidMagic, validateMagic(&data));
}

test "parseHeader guitar" {
    const testing = std.testing;
    var data: [32]u8 = [_]u8{0} ** 32;
    @memcpy(data[0..ptb_magic.len], &ptb_magic);
    data[6] = 0x07; // version = 7
    data[7] = 0x00;
    data[8] = 0x00; // guitar

    const result = try parseHeader(&data);
    try testing.expectEqual(@as(u16, 7), result.header.version);
    try testing.expectEqual(FileType.guitar, result.header.file_type);
}

test "parseHeader bass" {
    const testing = std.testing;
    var data: [32]u8 = [_]u8{0} ** 32;
    @memcpy(data[0..ptb_magic.len], &ptb_magic);
    data[6] = 0x07;
    data[7] = 0x00;
    data[8] = 0x01; // bass

    const result = try parseHeader(&data);
    try testing.expectEqual(FileType.bass, result.header.file_type);
}

test "writeHeader and parseHeader roundtrip" {
    const testing = std.testing;
    var buf: [64]u8 = [_]u8{0} ** 64;
    const header = PtbHeader{
        .version = FileVersion.v1_7,
        .file_type = .guitar,
    };
    const written = try writeHeader(&buf, header);
    try testing.expect(written > 0);

    const parsed = try parseHeader(&buf);
    try testing.expect(header.eql(parsed.header));
}

test "writeString and readString roundtrip" {
    const testing = std.testing;
    var buf: [64]u8 = undefined;
    const written = try writeString(&buf, 0, "Test Song");
    try testing.expectEqual(@as(usize, 10), written); // 1 + 9

    var read_buf: [64]u8 = undefined;
    const result = try readString(&buf, 0, &read_buf);
    try testing.expectEqualStrings("Test Song", read_buf[0..result.len]);
}

test "createScoreFromHeader guitar" {
    const testing = std.testing;
    var info = ScoreInfo{};
    info.setTitle("Test");
    const s = createScoreFromHeader(.{ .file_type = .guitar }, info);
    try testing.expectEqualStrings("Test", s.info.getTitle());
    try testing.expectEqualStrings("Player 1", s.players[0].getName());
}

test "createScoreFromHeader bass" {
    const testing = std.testing;
    const s = createScoreFromHeader(.{ .file_type = .bass }, ScoreInfo{});
    try testing.expectEqualStrings("Bass", s.players[0].getName());
    try testing.expectEqual(@as(u8, 4), s.players[0].tuning.num_strings);
}

test "readU16 out of bounds" {
    const testing = std.testing;
    const data = [_]u8{0};
    try testing.expectError(PowerTabError.UnexpectedEndOfFile, readU16(&data, 0));
}

test "readU8 out of bounds" {
    const testing = std.testing;
    const data = [_]u8{};
    try testing.expectError(PowerTabError.UnexpectedEndOfFile, readU8(&data, 0));
}

test "writeU16 and readU16 roundtrip" {
    const testing = std.testing;
    var buf: [4]u8 = undefined;
    _ = try writeU16(&buf, 0, 0xABCD);
    try testing.expectEqual(@as(u16, 0xABCD), try readU16(&buf, 0));
}

test "parseScoreInfo" {
    const testing = std.testing;
    // Build test data: title="Song", artist="Band"
    var data: [64]u8 = [_]u8{0} ** 64;
    data[0] = 4; // title len
    data[1] = 'S';
    data[2] = 'o';
    data[3] = 'n';
    data[4] = 'g';
    data[5] = 4; // artist len
    data[6] = 'B';
    data[7] = 'a';
    data[8] = 'n';
    data[9] = 'd';

    const result = try parseScoreInfo(&data, 0);
    try testing.expectEqualStrings("Song", result.info.getTitle());
    try testing.expectEqualStrings("Band", result.info.getArtist());
    try testing.expectEqual(@as(usize, 10), result.offset);
}
