const std = @import("std");
const note_mod = @import("note.zig");

pub const Note = note_mod.Note;
pub const Duration = note_mod.Duration;

/// A beat position within a measure – holds one or more notes played simultaneously.
pub const Position = struct {
    /// Duration of this beat.
    duration: Duration,
    /// Notes at this beat (chord). Owned by the parent Measure via its allocator.
    notes: []Note,
    /// True when this is a rest (no notes sounding).
    rest: bool,
    /// Optional chord name displayed above the beat (e.g. "Am7"). Owned slice.
    chord_name: ?[]const u8,

    pub fn init(duration: Duration, notes: []Note, rest: bool) Position {
        return .{
            .duration = duration,
            .notes = notes,
            .rest = rest,
            .chord_name = null,
        };
    }

    /// Returns true when this position contains at least one note with the
    /// given string index.
    pub fn hasString(self: Position, string: u8) bool {
        for (self.notes) |n| {
            if (n.string == string) return true;
        }
        return false;
    }

    /// Returns the note on `string`, or null if not present.
    pub fn noteOnString(self: Position, string: u8) ?Note {
        for (self.notes) |n| {
            if (n.string == string) return n;
        }
        return null;
    }
};

/// A single measure (bar) with a time signature and a sequence of positions.
pub const Measure = struct {
    /// Number of beats per measure.
    numerator: u8,
    /// Beat unit (4 = quarter note, 8 = eighth note, etc.).
    denominator: u8,
    /// Ordered list of beat positions. Owned slice.
    positions: []Position,
    /// True when a repeat starts at this bar.
    repeat_start: bool,
    /// Number of repeats ending at this bar (0 = no repeat end).
    repeat_end: u8,

    pub fn init(numerator: u8, denominator: u8, positions: []Position) Measure {
        return .{
            .numerator = numerator,
            .denominator = denominator,
            .positions = positions,
            .repeat_start = false,
            .repeat_end = 0,
        };
    }

    /// Returns total tick duration of this measure based on position durations.
    pub fn totalTicks(self: Measure) u32 {
        var total: u32 = 0;
        for (self.positions) |pos| {
            total += pos.duration.ticks();
        }
        return total;
    }

    /// Returns the expected tick duration given the time signature (at 960 PPQ).
    pub fn expectedTicks(self: Measure) u32 {
        const quarter_ticks: u32 = 960;
        return quarter_ticks * 4 * @as(u32, self.numerator) / @as(u32, self.denominator);
    }

    /// Returns true when the sum of position durations matches the time signature.
    pub fn isComplete(self: Measure) bool {
        return self.totalTicks() == self.expectedTicks();
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Position.hasString and noteOnString" {
    var notes = [_]Note{ Note.init(0, 3), Note.init(2, 5) };
    const pos = Position.init(.quarter, &notes, false);
    try std.testing.expect(pos.hasString(0));
    try std.testing.expect(pos.hasString(2));
    try std.testing.expect(!pos.hasString(1));
    try std.testing.expectEqual(Note.init(0, 3), pos.noteOnString(0).?);
    try std.testing.expect(pos.noteOnString(3) == null);
}

test "Measure.expectedTicks 4/4" {
    const m = Measure.init(4, 4, &.{});
    try std.testing.expectEqual(@as(u32, 3840), m.expectedTicks());
}

test "Measure.expectedTicks 3/4" {
    const m = Measure.init(3, 4, &.{});
    try std.testing.expectEqual(@as(u32, 2880), m.expectedTicks());
}

test "Measure.expectedTicks 6/8" {
    const m = Measure.init(6, 8, &.{});
    try std.testing.expectEqual(@as(u32, 2880), m.expectedTicks());
}

test "Measure.isComplete with quarter notes in 4/4" {
    var n = [_]Note{Note.init(0, 0)};
    var positions = [_]Position{
        Position.init(.quarter, &n, false),
        Position.init(.quarter, &n, false),
        Position.init(.quarter, &n, false),
        Position.init(.quarter, &n, false),
    };
    const m = Measure.init(4, 4, &positions);
    try std.testing.expect(m.isComplete());
}

test "Measure.isComplete returns false for partial fill" {
    var n = [_]Note{Note.init(0, 0)};
    var positions = [_]Position{Position.init(.quarter, &n, false)};
    const m = Measure.init(4, 4, &positions);
    try std.testing.expect(!m.isComplete());
}

test "Measure.totalTicks" {
    var n = [_]Note{Note.init(0, 0)};
    var positions = [_]Position{
        Position.init(.half, &n, false),
        Position.init(.quarter, &n, false),
        Position.init(.eighth, &n, false),
    };
    const m = Measure.init(4, 4, &positions);
    // 1920 + 960 + 480 = 3360
    try std.testing.expectEqual(@as(u32, 3360), m.totalTicks());
}
