const std = @import("std");
const guitar_mod = @import("guitar.zig");
const staff_mod = @import("staff.zig");

pub const Guitar = guitar_mod.Guitar;
pub const Staff = staff_mod.Staff;

/// Metadata describing the song.
pub const SongInfo = struct {
    title: []const u8,
    artist: []const u8,
    album: []const u8,
    tab_by: []const u8,
    copyright: []const u8,
    instructions: []const u8,
    notes: []const u8,
    /// Beats per minute.
    tempo: u16,
    /// MIDI ticks per quarter note (typically 960 in PowerTab).
    ticks_per_beat: u16,

    pub fn init() SongInfo {
        return .{
            .title = "",
            .artist = "",
            .album = "",
            .tab_by = "",
            .copyright = "",
            .instructions = "",
            .notes = "",
            .tempo = 120,
            .ticks_per_beat = 960,
        };
    }
};

/// The top-level song object containing all score data.
pub const Song = struct {
    info: SongInfo,
    /// Guitar/instrument definitions.
    guitars: []Guitar,
    /// One staff per guitar part (may be more if there are multiple passes).
    staves: []Staff,
    /// Memory arena backing all allocations in this song.
    arena: std.heap.ArenaAllocator,

    /// Create an empty song backed by the given child allocator.
    pub fn init(child_allocator: std.mem.Allocator) Song {
        return .{
            .info = SongInfo.init(),
            .guitars = &.{},
            .staves = &.{},
            .arena = std.heap.ArenaAllocator.init(child_allocator),
        };
    }

    /// Release all memory associated with this song.
    pub fn deinit(self: *Song) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *Song) std.mem.Allocator {
        return self.arena.allocator();
    }

    /// Returns the number of measures in the first staff, or 0 if empty.
    pub fn measureCount(self: Song) usize {
        if (self.staves.len == 0) return 0;
        return self.staves[0].measures.len;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "SongInfo defaults" {
    const info = SongInfo.init();
    try std.testing.expectEqual(@as(u16, 120), info.tempo);
    try std.testing.expectEqualStrings("", info.title);
}

test "Song.init and deinit" {
    var song = Song.init(std.testing.allocator);
    defer song.deinit();
    try std.testing.expectEqual(@as(usize, 0), song.measureCount());
}

test "Song.measureCount with staves" {
    var song = Song.init(std.testing.allocator);
    defer song.deinit();

    const alloc = song.allocator();
    const Measure = @import("measure.zig").Measure;
    const measures = try alloc.alloc(Measure, 4);
    for (measures) |*m| m.* = Measure.init(4, 4, &.{});
    const staves = try alloc.alloc(Staff, 1);
    staves[0] = Staff.init(0, measures);
    song.staves = staves;

    try std.testing.expectEqual(@as(usize, 4), song.measureCount());
}
