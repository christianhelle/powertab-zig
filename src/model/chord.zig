const std = @import("std");

/// A chord diagram stores the fret number for each string (255 = muted/not played).
pub const CHORD_STRINGS = 6;
pub const MUTED: u8 = 255;

pub const ChordDiagram = struct {
    /// Name displayed above the diagram (e.g. "Am", "D/F#").
    name: []const u8,
    /// Fret number at which the diagram is positioned (0 = nut).
    base_fret: u8,
    /// Per-string fret offsets from `base_fret`; MUTED means that string is not played.
    frets: [CHORD_STRINGS]u8,

    pub fn init(name: []const u8, base_fret: u8, frets: [CHORD_STRINGS]u8) ChordDiagram {
        return .{
            .name = name,
            .base_fret = base_fret,
            .frets = frets,
        };
    }

    /// Returns the absolute fret on string `s`, or null if muted.
    pub fn absoluteFret(self: ChordDiagram, s: u8) ?u8 {
        std.debug.assert(s < CHORD_STRINGS);
        if (self.frets[s] == MUTED) return null;
        return self.base_fret + self.frets[s];
    }

    /// Returns true if the diagram has no playable strings.
    pub fn isEmpty(self: ChordDiagram) bool {
        for (self.frets) |f| {
            if (f != MUTED) return false;
        }
        return true;
    }

    /// Returns the number of playable strings.
    pub fn playableCount(self: ChordDiagram) u8 {
        var count: u8 = 0;
        for (self.frets) |f| {
            if (f != MUTED) count += 1;
        }
        return count;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "ChordDiagram.absoluteFret" {
    // A major chord: x02220
    const frets = [CHORD_STRINGS]u8{ MUTED, 0, 2, 2, 2, 0 };
    const chord = ChordDiagram.init("A", 0, frets);
    try std.testing.expect(chord.absoluteFret(0) == null); // muted
    try std.testing.expectEqual(@as(u8, 0), chord.absoluteFret(1).?);
    try std.testing.expectEqual(@as(u8, 2), chord.absoluteFret(2).?);
}

test "ChordDiagram.isEmpty" {
    const all_muted = [CHORD_STRINGS]u8{ MUTED, MUTED, MUTED, MUTED, MUTED, MUTED };
    const c = ChordDiagram.init("", 0, all_muted);
    try std.testing.expect(c.isEmpty());

    const frets = [CHORD_STRINGS]u8{ 0, 0, 0, 0, 0, 0 };
    const c2 = ChordDiagram.init("Em", 0, frets);
    try std.testing.expect(!c2.isEmpty());
}

test "ChordDiagram.playableCount" {
    // A major: x02220 – 5 playable strings
    const frets = [CHORD_STRINGS]u8{ MUTED, 0, 2, 2, 2, 0 };
    const chord = ChordDiagram.init("A", 0, frets);
    try std.testing.expectEqual(@as(u8, 5), chord.playableCount());
}

test "ChordDiagram with base_fret" {
    // Barre chord at fret 5: all strings fret 0 from base_fret 5
    const frets = [CHORD_STRINGS]u8{ 0, 0, 0, 0, 0, 0 };
    const chord = ChordDiagram.init("A barre", 5, frets);
    for (0..CHORD_STRINGS) |s| {
        try std.testing.expectEqual(@as(u8, 5), chord.absoluteFret(@intCast(s)).?);
    }
}
