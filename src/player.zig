/// Player and Instrument definitions for the score.
/// A Player represents a musician; an Instrument holds MIDI settings.
const tuning_mod = @import("tuning.zig");
const Tuning = tuning_mod.Tuning;

/// Represents a player (musician) in the score.
pub const Player = struct {
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: u8 = 0,
    tuning: Tuning = Tuning.standardGuitar(),
    max_volume: u8 = 127,
    pan: u8 = 64,

    pub fn init(name: []const u8) Player {
        var p = Player{};
        p.setName(name);
        return p;
    }

    pub fn setName(self: *Player, name: []const u8) void {
        const len: u8 = @intCast(@min(name.len, self.name.len));
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn getName(self: *const Player) []const u8 {
        return self.name[0..self.name_len];
    }
};

/// Represents a MIDI instrument configuration.
pub const Instrument = struct {
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: u8 = 0,
    midi_preset: u8 = 25, // Steel string acoustic guitar
    volume: u8 = 104,
    pan: u8 = 64,
    reverb: u8 = 0,
    chorus: u8 = 0,
    tremolo: u8 = 0,
    phaser: u8 = 0,

    pub fn init(name: []const u8, preset: u8) Instrument {
        var inst = Instrument{};
        inst.setName(name);
        inst.midi_preset = preset;
        return inst;
    }

    pub fn setName(self: *Instrument, name: []const u8) void {
        const len: u8 = @intCast(@min(name.len, self.name.len));
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn getName(self: *const Instrument) []const u8 {
        return self.name[0..self.name_len];
    }

    /// Common MIDI presets.
    pub const acoustic_nylon: u8 = 24;
    pub const acoustic_steel: u8 = 25;
    pub const electric_jazz: u8 = 26;
    pub const electric_clean: u8 = 27;
    pub const electric_muted: u8 = 28;
    pub const overdriven: u8 = 29;
    pub const distortion: u8 = 30;
    pub const harmonics: u8 = 31;
    pub const acoustic_bass: u8 = 32;
    pub const electric_bass_finger: u8 = 33;
    pub const electric_bass_pick: u8 = 34;
};

/// Player-instrument assignment at a specific position.
pub const PlayerChange = struct {
    position: u32 = 0,
    player_index: u8 = 0,
    instrument_index: u8 = 0,
    active_player_count: u8 = 0,

    pub fn init(position: u32, player: u8, instrument: u8) PlayerChange {
        return .{
            .position = position,
            .player_index = player,
            .instrument_index = instrument,
            .active_player_count = 1,
        };
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "Player init and name" {
    const testing = @import("std").testing;
    const p = Player.init("Guitar 1");
    try testing.expectEqualStrings("Guitar 1", p.getName());
    try testing.expectEqual(@as(u8, 127), p.max_volume);
}

test "Player default tuning is standard guitar" {
    const testing = @import("std").testing;
    const p = Player.init("Test");
    try testing.expectEqual(@as(u8, 6), p.tuning.num_strings);
    try testing.expectEqual(@as(u8, 40), p.tuning.getNote(0));
}

test "Instrument init and MIDI preset" {
    const testing = @import("std").testing;
    const inst = Instrument.init("Clean Electric", Instrument.electric_clean);
    try testing.expectEqualStrings("Clean Electric", inst.getName());
    try testing.expectEqual(@as(u8, 27), inst.midi_preset);
}

test "Instrument defaults" {
    const testing = @import("std").testing;
    const inst = Instrument{};
    try testing.expectEqual(@as(u8, 25), inst.midi_preset); // Steel acoustic
    try testing.expectEqual(@as(u8, 104), inst.volume);
    try testing.expectEqual(@as(u8, 64), inst.pan);
}

test "PlayerChange init" {
    const testing = @import("std").testing;
    const pc = PlayerChange.init(0, 0, 0);
    try testing.expectEqual(@as(u32, 0), pc.position);
    try testing.expectEqual(@as(u8, 0), pc.player_index);
    try testing.expectEqual(@as(u8, 0), pc.instrument_index);
    try testing.expectEqual(@as(u8, 1), pc.active_player_count);
}
