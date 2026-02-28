/// Guitar Pro file format parser (.gp3/.gp4/.gp5 files).
/// Guitar Pro is a popular tablature editor; this module reads
/// the binary format and converts it into our Score model.
///
/// File structure overview:
/// - Header: version string, title, artist, album, etc.
/// - Tempo, key, time signature
/// - Tracks (instruments/players)
/// - Measures with notes and effects
const std = @import("std");
const score_mod = @import("score.zig");
const player_mod = @import("player.zig");
const tuning_mod = @import("tuning.zig");
const music_theory = @import("music_theory.zig");

const Score = score_mod.Score;
const ScoreInfo = score_mod.ScoreInfo;
const Player = player_mod.Player;
const Instrument = player_mod.Instrument;
const Tuning = tuning_mod.Tuning;

pub const GpError = error{
    InvalidMagic,
    UnsupportedVersion,
    UnexpectedEndOfFile,
    InvalidData,
};

/// Guitar Pro version identifiers.
pub const GpVersion = enum(u8) {
    gp3,
    gp4,
    gp5,
    unknown,
};

/// Guitar Pro file magic/version strings.
pub const gp3_magic = "FICHIER GUITAR PRO v3.00";
pub const gp4_magic = "FICHIER GUITAR PRO v4.00";
pub const gp5_magic = "FICHIER GUITAR PRO v5.00";
pub const gp5_10_magic = "FICHIER GUITAR PRO v5.10";

/// Reads a little-endian i32 from a byte slice.
pub fn readI32(data: []const u8, offset: usize) GpError!i32 {
    if (offset + 4 > data.len) return GpError.UnexpectedEndOfFile;
    const unsigned: u32 = @as(u32, data[offset]) |
        (@as(u32, data[offset + 1]) << 8) |
        (@as(u32, data[offset + 2]) << 16) |
        (@as(u32, data[offset + 3]) << 24);
    return @bitCast(unsigned);
}

/// Reads a single byte.
pub fn readByte(data: []const u8, offset: usize) GpError!u8 {
    if (offset >= data.len) return GpError.UnexpectedEndOfFile;
    return data[offset];
}

/// Reads an i32-length-prefixed string (GP format).
pub fn readGpString(data: []const u8, offset: usize, buf: []u8) GpError!struct { len: usize, bytes_read: usize } {
    const str_len_i32 = try readI32(data, offset);
    if (str_len_i32 < 0) return GpError.InvalidData;
    const str_len: usize = @intCast(str_len_i32);
    if (offset + 4 + str_len > data.len) return GpError.UnexpectedEndOfFile;
    const copy_len = @min(str_len, buf.len);
    @memcpy(buf[0..copy_len], data[offset + 4 .. offset + 4 + copy_len]);
    return .{ .len = copy_len, .bytes_read = 4 + str_len };
}

/// Detects Guitar Pro version from the version string at the start of file.
pub fn detectVersion(data: []const u8) GpError!struct { version: GpVersion, offset: usize } {
    if (data.len < 31) return GpError.UnexpectedEndOfFile;

    // GP files start with a byte-length prefix followed by version string
    const str_len = data[0];
    if (str_len == 0 or @as(usize, str_len) + 1 > data.len) return GpError.InvalidMagic;

    const version_str = data[1 .. 1 + str_len];

    if (std.mem.startsWith(u8, version_str, gp5_10_magic) or
        std.mem.startsWith(u8, version_str, gp5_magic))
    {
        return .{ .version = .gp5, .offset = 31 };
    }
    if (std.mem.startsWith(u8, version_str, gp4_magic)) {
        return .{ .version = .gp4, .offset = 31 };
    }
    if (std.mem.startsWith(u8, version_str, gp3_magic)) {
        return .{ .version = .gp3, .offset = 31 };
    }

    return GpError.InvalidMagic;
}

/// Parse score info from Guitar Pro data.
pub fn parseGpScoreInfo(data: []const u8, start_offset: usize) GpError!struct { info: ScoreInfo, offset: usize } {
    var info = ScoreInfo{};
    var offset = start_offset;

    // Title
    var title_buf: [128]u8 = undefined;
    const title_result = try readGpString(data, offset, &title_buf);
    info.setTitle(title_buf[0..title_result.len]);
    offset += title_result.bytes_read;

    // Subtitle (skip)
    var skip_buf: [128]u8 = undefined;
    const subtitle_result = try readGpString(data, offset, &skip_buf);
    offset += subtitle_result.bytes_read;

    // Artist
    var artist_buf: [128]u8 = undefined;
    const artist_result = try readGpString(data, offset, &artist_buf);
    info.setArtist(artist_buf[0..artist_result.len]);
    offset += artist_result.bytes_read;

    // Album
    var album_buf: [128]u8 = undefined;
    const album_result = try readGpString(data, offset, &album_buf);
    info.setAlbum(album_buf[0..album_result.len]);
    offset += album_result.bytes_read;

    return .{ .info = info, .offset = offset };
}

/// Creates a default Score from Guitar Pro metadata.
pub fn createScoreFromGp(version: GpVersion, info: ScoreInfo) Score {
    _ = version;
    var s = Score.init();
    s.info = info;
    return s;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "readI32 little-endian" {
    const testing = std.testing;
    const data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    try testing.expectEqual(@as(i32, 0x12345678), try readI32(&data, 0));
}

test "readI32 negative" {
    const testing = std.testing;
    const data = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
    try testing.expectEqual(@as(i32, -1), try readI32(&data, 0));
}

test "readByte" {
    const testing = std.testing;
    const data = [_]u8{42};
    try testing.expectEqual(@as(u8, 42), try readByte(&data, 0));
}

test "readGpString" {
    const testing = std.testing;
    // length = 5, then "Hello"
    const data = [_]u8{ 5, 0, 0, 0, 'H', 'e', 'l', 'l', 'o' };
    var buf: [32]u8 = undefined;
    const result = try readGpString(&data, 0, &buf);
    try testing.expectEqual(@as(usize, 5), result.len);
    try testing.expectEqualStrings("Hello", buf[0..result.len]);
    try testing.expectEqual(@as(usize, 9), result.bytes_read);
}

test "detectVersion GP3" {
    const testing = std.testing;
    var data: [64]u8 = [_]u8{0} ** 64;
    const magic = gp3_magic;
    data[0] = @intCast(magic.len);
    @memcpy(data[1 .. 1 + magic.len], magic);

    const result = try detectVersion(&data);
    try testing.expectEqual(GpVersion.gp3, result.version);
}

test "detectVersion GP4" {
    const testing = std.testing;
    var data: [64]u8 = [_]u8{0} ** 64;
    const magic = gp4_magic;
    data[0] = @intCast(magic.len);
    @memcpy(data[1 .. 1 + magic.len], magic);

    const result = try detectVersion(&data);
    try testing.expectEqual(GpVersion.gp4, result.version);
}

test "detectVersion GP5" {
    const testing = std.testing;
    var data: [64]u8 = [_]u8{0} ** 64;
    const magic = gp5_magic;
    data[0] = @intCast(magic.len);
    @memcpy(data[1 .. 1 + magic.len], magic);

    const result = try detectVersion(&data);
    try testing.expectEqual(GpVersion.gp5, result.version);
}

test "detectVersion invalid" {
    const testing = std.testing;
    var data: [64]u8 = [_]u8{0} ** 64;
    data[0] = 10;
    @memcpy(data[1..11], "NOT GUITAR");

    try testing.expectError(GpError.InvalidMagic, detectVersion(&data));
}

test "readI32 out of bounds" {
    const testing = std.testing;
    const data = [_]u8{ 0, 0, 0 };
    try testing.expectError(GpError.UnexpectedEndOfFile, readI32(&data, 0));
}

test "readGpString negative length" {
    const testing = std.testing;
    const data = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
    var buf: [32]u8 = undefined;
    try testing.expectError(GpError.InvalidData, readGpString(&data, 0, &buf));
}

test "parseGpScoreInfo" {
    const testing = std.testing;
    var data: [256]u8 = [_]u8{0} ** 256;
    var off: usize = 0;

    // Title = "Song"
    data[off] = 4;
    off += 4;
    @memcpy(data[off .. off + 4], "Song");
    off += 4;

    // Subtitle = ""
    data[off] = 0;
    off += 4;

    // Artist = "Band"
    data[off] = 4;
    off += 4;
    @memcpy(data[off .. off + 4], "Band");
    off += 4;

    // Album = "Disc"
    data[off] = 4;
    off += 4;
    @memcpy(data[off .. off + 4], "Disc");
    off += 4;

    const result = try parseGpScoreInfo(&data, 0);
    try testing.expectEqualStrings("Song", result.info.getTitle());
    try testing.expectEqualStrings("Band", result.info.getArtist());
    try testing.expectEqualStrings("Disc", result.info.getAlbum());
}

test "createScoreFromGp" {
    const testing = std.testing;
    var info = ScoreInfo{};
    info.setTitle("GP Song");
    const s = createScoreFromGp(.gp5, info);
    try testing.expectEqualStrings("GP Song", s.info.getTitle());
    try testing.expectEqual(@as(u8, 1), s.system_count);
}
