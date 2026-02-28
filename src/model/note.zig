const std = @import("std");

/// Note duration expressed in MIDI ticks at the standard PowerTab resolution
/// of 960 pulses per quarter note (PPQ).  This matches `SongInfo.ticks_per_beat`.
pub const Duration = enum(u8) {
    whole = 0,
    half = 1,
    quarter = 2,
    eighth = 3,
    sixteenth = 4,
    thirty_second = 5,
    sixty_fourth = 6,

    pub fn ticks(self: Duration) u32 {
        return switch (self) {
            .whole => 3840,
            .half => 1920,
            .quarter => 960,
            .eighth => 480,
            .sixteenth => 240,
            .thirty_second => 120,
            .sixty_fourth => 60,
        };
    }

    pub fn fromTicks(t: u32) ?Duration {
        return switch (t) {
            3840 => .whole,
            1920 => .half,
            960 => .quarter,
            480 => .eighth,
            240 => .sixteenth,
            120 => .thirty_second,
            60 => .sixty_fourth,
            else => null,
        };
    }

    /// Returns the display string for rendering (e.g. "♩").
    pub fn symbol(self: Duration) []const u8 {
        return switch (self) {
            .whole => "o",
            .half => "h",
            .quarter => "q",
            .eighth => "e",
            .sixteenth => "s",
            .thirty_second => "t",
            .sixty_fourth => "x",
        };
    }
};

/// Bit-packed playing techniques attached to an individual note.
pub const Technique = packed struct(u16) {
    tied: bool = false,
    muted: bool = false,
    hammer_on: bool = false,
    pull_off: bool = false,
    bend: bool = false,
    bend_and_release: bool = false,
    slide_up: bool = false,
    slide_down: bool = false,
    vibrato: bool = false,
    harmonic_natural: bool = false,
    harmonic_artificial: bool = false,
    tremolo_pick: bool = false,
    trill: bool = false,
    tap: bool = false,
    slap: bool = false,
    pop: bool = false,
};

/// A single fretted note on a specific string.
pub const Note = struct {
    /// 0-based string index (0 = highest-pitched string).
    string: u8,
    /// Fret number (0 = open, 1-24 = fretted).
    fret: u8,
    /// Playing techniques applied to this note.
    technique: Technique,

    pub fn init(string: u8, fret: u8) Note {
        return .{
            .string = string,
            .fret = fret,
            .technique = .{},
        };
    }

    /// Returns true when string and fret values are within legal ranges.
    pub fn isValid(self: Note) bool {
        return self.string < 7 and self.fret <= 24;
    }

    /// Computes the MIDI pitch given the open-string MIDI pitches.
    /// `open_pitches` must have at least `string + 1` elements.
    pub fn midiPitch(self: Note, open_pitches: []const u8) u8 {
        std.debug.assert(self.string < open_pitches.len);
        return open_pitches[self.string] + self.fret;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Duration.ticks roundtrip" {
    const cases = [_]Duration{ .whole, .half, .quarter, .eighth, .sixteenth, .thirty_second, .sixty_fourth };
    for (cases) |d| {
        const t = d.ticks();
        try std.testing.expectEqual(d, Duration.fromTicks(t).?);
    }
}

test "Duration.ticks values" {
    try std.testing.expectEqual(@as(u32, 3840), Duration.whole.ticks());
    try std.testing.expectEqual(@as(u32, 1920), Duration.half.ticks());
    try std.testing.expectEqual(@as(u32, 960), Duration.quarter.ticks());
    try std.testing.expectEqual(@as(u32, 480), Duration.eighth.ticks());
}

test "Duration.fromTicks returns null for unknown value" {
    try std.testing.expect(Duration.fromTicks(100) == null);
    try std.testing.expect(Duration.fromTicks(0) == null);
}

test "Note.init" {
    const n = Note.init(2, 7);
    try std.testing.expectEqual(@as(u8, 2), n.string);
    try std.testing.expectEqual(@as(u8, 7), n.fret);
    try std.testing.expect(!n.technique.hammer_on);
}

test "Note.isValid" {
    try std.testing.expect(Note.init(0, 0).isValid());
    try std.testing.expect(Note.init(5, 24).isValid());
    try std.testing.expect(!Note{ .string = 7, .fret = 0, .technique = .{} }.isValid());
    try std.testing.expect(!Note{ .string = 0, .fret = 25, .technique = .{} }.isValid());
}

test "Note.midiPitch" {
    // Standard tuning open pitches (high-E first)
    const tuning = [6]u8{ 64, 59, 55, 50, 45, 40 };
    const n = Note.init(0, 5); // E4 + 5 frets = A4
    try std.testing.expectEqual(@as(u8, 69), n.midiPitch(&tuning));
}

test "Technique flags are independent" {
    var t = Technique{};
    t.hammer_on = true;
    try std.testing.expect(t.hammer_on);
    try std.testing.expect(!t.pull_off);
    t.pull_off = true;
    try std.testing.expect(t.hammer_on);
    try std.testing.expect(t.pull_off);
}
