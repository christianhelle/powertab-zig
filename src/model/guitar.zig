const std = @import("std");

/// Standard MIDI pitches for an open guitar string (index 0 = highest/thinnest).
/// Standard tuning: E4 B3 G3 D3 A2 E2
pub const STANDARD_TUNING = [6]u8{ 64, 59, 55, 50, 45, 40 };
/// Drop-D tuning: E4 B3 G3 D3 A2 D2
pub const DROP_D_TUNING = [6]u8{ 64, 59, 55, 50, 45, 38 };
/// Open G tuning: D4 B3 G3 D3 G2 D2
pub const OPEN_G_TUNING = [6]u8{ 62, 59, 55, 50, 43, 38 };

pub const MAX_STRINGS = 8;

/// Guitar configuration (tuning, number of strings, capo, etc.).
pub const Guitar = struct {
    /// Display name (e.g. "Guitar 1", "Bass").
    name: []const u8,
    /// Number of strings (typically 6, may be 4 for bass, 7 for 7-string).
    string_count: u8,
    /// MIDI pitch of each open string (index 0 = highest pitch).
    tuning: [MAX_STRINGS]u8,
    /// Capo position (0 = no capo).
    capo: u8,
    /// MIDI channel (0-15).
    midi_channel: u8,
    /// MIDI program/patch (0-127).
    midi_program: u8,
    /// Initial volume (0-127).
    volume: u8,
    /// True when this guitar is muted in playback.
    muted: bool,

    /// Initialise a standard 6-string guitar with default values.
    pub fn initDefault(name: []const u8) Guitar {
        var tuning: [MAX_STRINGS]u8 = [_]u8{0} ** MAX_STRINGS;
        @memcpy(tuning[0..6], &STANDARD_TUNING);
        return .{
            .name = name,
            .string_count = 6,
            .tuning = tuning,
            .capo = 0,
            .midi_channel = 0,
            .midi_program = 25, // Acoustic Steel Guitar
            .volume = 100,
            .muted = false,
        };
    }

    /// Returns the MIDI pitch for the given string and fret, accounting for capo.
    pub fn midiPitch(self: Guitar, string: u8, fret: u8) u8 {
        std.debug.assert(string < self.string_count);
        return self.tuning[string] + fret + self.capo;
    }

    /// Returns a slice of the active string tunings.
    pub fn activeTuning(self: *const Guitar) []const u8 {
        return self.tuning[0..self.string_count];
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Guitar.initDefault standard 6-string" {
    const g = Guitar.initDefault("Guitar 1");
    try std.testing.expectEqual(@as(u8, 6), g.string_count);
    try std.testing.expectEqual(@as(u8, 0), g.capo);
    try std.testing.expectEqual(STANDARD_TUNING[0], g.tuning[0]);
}

test "Guitar.midiPitch open strings" {
    const g = Guitar.initDefault("Guitar 1");
    // Open high-E string (string 0, fret 0) = 64
    try std.testing.expectEqual(@as(u8, 64), g.midiPitch(0, 0));
    // Open low-E string (string 5, fret 0) = 40
    try std.testing.expectEqual(@as(u8, 40), g.midiPitch(5, 0));
}

test "Guitar.midiPitch with fret" {
    const g = Guitar.initDefault("Guitar 1");
    // String 0 (E4=64), fret 5 = A4 = 69
    try std.testing.expectEqual(@as(u8, 69), g.midiPitch(0, 5));
}

test "Guitar.midiPitch with capo" {
    var g = Guitar.initDefault("Guitar 1");
    g.capo = 2;
    // String 0 open (64) + capo 2 = 66
    try std.testing.expectEqual(@as(u8, 66), g.midiPitch(0, 0));
}

test "Guitar.activeTuning length" {
    const g = Guitar.initDefault("Guitar 1");
    try std.testing.expectEqual(@as(usize, 6), g.activeTuning().len);
}
