/// Score — the top-level document model for PowerTab Editor.
/// Contains all systems, players, instruments, and metadata.
const system_mod = @import("system.zig");
const player_mod = @import("player.zig");
const music_theory = @import("music_theory.zig");

const System = system_mod.System;
const Player = player_mod.Player;
const Instrument = player_mod.Instrument;

pub const max_systems: u8 = 32;
pub const max_players: u8 = 16;
pub const max_instruments: u8 = 16;

/// Score metadata (title, artist, etc.)
pub const ScoreInfo = struct {
    title: [128]u8 = [_]u8{0} ** 128,
    title_len: u8 = 0,
    artist: [128]u8 = [_]u8{0} ** 128,
    artist_len: u8 = 0,
    album: [128]u8 = [_]u8{0} ** 128,
    album_len: u8 = 0,
    author: [128]u8 = [_]u8{0} ** 128,
    author_len: u8 = 0,
    copyright: [128]u8 = [_]u8{0} ** 128,
    copyright_len: u8 = 0,
    transcriber: [128]u8 = [_]u8{0} ** 128,
    transcriber_len: u8 = 0,

    pub fn setTitle(self: *ScoreInfo, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, self.title.len));
        @memcpy(self.title[0..len], text[0..len]);
        self.title_len = len;
    }
    pub fn getTitle(self: *const ScoreInfo) []const u8 {
        return self.title[0..self.title_len];
    }

    pub fn setArtist(self: *ScoreInfo, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, self.artist.len));
        @memcpy(self.artist[0..len], text[0..len]);
        self.artist_len = len;
    }
    pub fn getArtist(self: *const ScoreInfo) []const u8 {
        return self.artist[0..self.artist_len];
    }

    pub fn setAlbum(self: *ScoreInfo, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, self.album.len));
        @memcpy(self.album[0..len], text[0..len]);
        self.album_len = len;
    }
    pub fn getAlbum(self: *const ScoreInfo) []const u8 {
        return self.album[0..self.album_len];
    }

    pub fn setAuthor(self: *ScoreInfo, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, self.author.len));
        @memcpy(self.author[0..len], text[0..len]);
        self.author_len = len;
    }
    pub fn getAuthor(self: *const ScoreInfo) []const u8 {
        return self.author[0..self.author_len];
    }

    pub fn setCopyright(self: *ScoreInfo, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, self.copyright.len));
        @memcpy(self.copyright[0..len], text[0..len]);
        self.copyright_len = len;
    }
    pub fn getCopyright(self: *const ScoreInfo) []const u8 {
        return self.copyright[0..self.copyright_len];
    }

    pub fn setTranscriber(self: *ScoreInfo, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, self.transcriber.len));
        @memcpy(self.transcriber[0..len], text[0..len]);
        self.transcriber_len = len;
    }
    pub fn getTranscriber(self: *const ScoreInfo) []const u8 {
        return self.transcriber[0..self.transcriber_len];
    }
};

/// The top-level Score document model.
pub const Score = struct {
    info: ScoreInfo = ScoreInfo{},
    systems: [max_systems]System = undefined,
    system_count: u8 = 0,
    players: [max_players]Player = undefined,
    player_count: u8 = 0,
    instruments: [max_instruments]Instrument = undefined,
    instrument_count: u8 = 0,
    line_spacing: u8 = 9,

    pub fn init() Score {
        var s = Score{};
        // Initialize with one system, one player, one instrument
        s.systems[0] = System.init();
        s.system_count = 1;
        s.players[0] = Player.init("Player 1");
        s.player_count = 1;
        s.instruments[0] = Instrument.init("Acoustic Guitar", Instrument.acoustic_steel);
        s.instrument_count = 1;
        return s;
    }

    pub fn addSystem(self: *Score, sys: System) bool {
        if (self.system_count >= max_systems) return false;
        self.systems[self.system_count] = sys;
        self.system_count += 1;
        return true;
    }

    pub fn getSystem(self: *const Score, idx: u8) *const System {
        if (idx >= self.system_count) return &self.systems[0];
        return &self.systems[idx];
    }

    pub fn getSystemMut(self: *Score, idx: u8) *System {
        if (idx >= self.system_count) return &self.systems[0];
        return &self.systems[idx];
    }

    pub fn addPlayer(self: *Score, p: Player) bool {
        if (self.player_count >= max_players) return false;
        self.players[self.player_count] = p;
        self.player_count += 1;
        return true;
    }

    pub fn addInstrument(self: *Score, inst: Instrument) bool {
        if (self.instrument_count >= max_instruments) return false;
        self.instruments[self.instrument_count] = inst;
        self.instrument_count += 1;
        return true;
    }

    pub fn getPlayers(self: *const Score) []const Player {
        return self.players[0..self.player_count];
    }

    pub fn getInstruments(self: *const Score) []const Instrument {
        return self.instruments[0..self.instrument_count];
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "ScoreInfo fields" {
    const testing = @import("std").testing;
    var info = ScoreInfo{};
    info.setTitle("Stairway to Heaven");
    info.setArtist("Led Zeppelin");
    info.setAlbum("Led Zeppelin IV");
    info.setAuthor("Jimmy Page / Robert Plant");
    try testing.expectEqualStrings("Stairway to Heaven", info.getTitle());
    try testing.expectEqualStrings("Led Zeppelin", info.getArtist());
    try testing.expectEqualStrings("Led Zeppelin IV", info.getAlbum());
    try testing.expectEqualStrings("Jimmy Page / Robert Plant", info.getAuthor());
}

test "Score init creates defaults" {
    const testing = @import("std").testing;
    const s = Score.init();
    try testing.expectEqual(@as(u8, 1), s.system_count);
    try testing.expectEqual(@as(u8, 1), s.player_count);
    try testing.expectEqual(@as(u8, 1), s.instrument_count);
    try testing.expectEqual(@as(u8, 9), s.line_spacing);
    try testing.expectEqualStrings("Player 1", s.players[0].getName());
}

test "Score add systems" {
    const testing = @import("std").testing;
    var s = Score.init();
    try testing.expect(s.addSystem(System.init()));
    try testing.expectEqual(@as(u8, 2), s.system_count);
}

test "Score add players and instruments" {
    const testing = @import("std").testing;
    var s = Score.init();
    try testing.expect(s.addPlayer(Player.init("Bass")));
    try testing.expectEqual(@as(u8, 2), s.player_count);
    try testing.expectEqualStrings("Bass", s.getPlayers()[1].getName());

    try testing.expect(s.addInstrument(Instrument.init("Bass", Instrument.acoustic_bass)));
    try testing.expectEqual(@as(u8, 2), s.instrument_count);
}

test "Score metadata" {
    const testing = @import("std").testing;
    var s = Score.init();
    s.info.setTitle("Test Song");
    s.info.setCopyright("2025");
    s.info.setTranscriber("PowerTab Zig");
    try testing.expectEqualStrings("Test Song", s.info.getTitle());
    try testing.expectEqualStrings("2025", s.info.getCopyright());
    try testing.expectEqualStrings("PowerTab Zig", s.info.getTranscriber());
}
